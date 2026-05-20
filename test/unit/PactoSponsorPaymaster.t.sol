// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {SIG_VALIDATION_FAILED} from '@account-abstraction/core/Helpers.sol';
import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';
import {MockSmartAccount} from 'test/unit/helpers/TestHelpers.sol';

/**
 * @title UnitPactoSponsorPaymaster
 * @author Pacto
 * @notice Unit tests for paymaster validation and vault billing.
 */
contract UnitPactoSponsorPaymaster is UnitSquadSponsorBase {
  address internal _member = makeAddr('member');
  address internal _vault;
  address internal _ext;

  function setUp() public override {
    super.setUp();
    vm.deal(_member, 10 ether);
    vm.deal(address(this), 5 ether);
    (_vault, _ext) = _createSquadWithDeposit(_squadId, 5 ether);
    SquadSponsorExt(_ext).setPermittedAddress(_member, true);
  }

  function test_Unit_Paymaster_ValidatesExtEligibility() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, address(0));

    vm.prank(_ENTRY_POINT);
    (bytes memory _context, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, 0);
    assertEq(_context, abi.encode(_vault));
  }

  function test_Unit_Paymaster_RejectsIneligibleMember() external {
    address _outsider = makeAddr('outsider');
    PackedUserOperation memory _userOp = _buildUserOp(_outsider, _outsider, address(0));

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_Paymaster_PostOpSpendsFromVault() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, address(0));

    vm.prank(_ENTRY_POINT);
    (bytes memory _context,) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    uint256 _balanceBefore = address(_paymaster).balance;
    vm.prank(_ENTRY_POINT);
    _paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, _context, 1 ether, 0);

    assertEq(address(_vault).balance, 4 ether);
    assertEq(address(_paymaster).balance - _balanceBefore, 1 ether);
  }

  function test_Unit_Paymaster_RoutesToHatBaseWhenWired() external {
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = 0xBEEF;
    address _base = _factory.cloneAndWireSquadSponsor(_squadId, 0x100, address(0), _customHats);

    _mockHatWearer(_member, 0xBEEF, true);
    SquadSponsorExt(_ext).setPermittedAddress(_member, false);

    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, _base);

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, 0);
  }

  function test_Unit_Paymaster_RejectsInsufficientVaultBalance() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, address(0));

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 5 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_Paymaster_RejectsCloneMismatchWrongVault() external {
    address _wrongVault = makeAddr('wrongVault');
    PackedUserOperation memory _userOp = _buildUserOpWithVault(_member, _member, address(0), _wrongVault, _ext);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(
      abi.encodeWithSelector(PactoSponsorPaymaster.PactoSponsorPaymaster_CloneMismatch.selector, _squadId)
    );
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_RejectsBaseWhenNotWired() external {
    address _base = makeAddr('unexpectedBase');
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, _base);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(
      abi.encodeWithSelector(PactoSponsorPaymaster.PactoSponsorPaymaster_CloneMismatch.selector, _squadId)
    );
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_RejectsMissingBaseWhenWired() external {
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = 0xBEEF;
    _factory.cloneAndWireSquadSponsor(_squadId, 0x100, address(0), _customHats);

    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, address(0));

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(
      abi.encodeWithSelector(PactoSponsorPaymaster.PactoSponsorPaymaster_CloneMismatch.selector, _squadId)
    );
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_RejectsWrongBaseWhenWired() external {
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = 0xBEEF;
    address _base = _factory.cloneAndWireSquadSponsor(_squadId, 0x100, address(0), _customHats);

    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, makeAddr('wrongBase'));

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(
      abi.encodeWithSelector(PactoSponsorPaymaster.PactoSponsorPaymaster_CloneMismatch.selector, _squadId)
    );
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    _mockHatWearer(_member, 0xBEEF, true);
    _userOp = _buildUserOp(_member, _member, _base);

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
    assertEq(_validationData, 0);
  }

  function test_Unit_Paymaster_RejectsZeroMember() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, address(0), address(0));

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_Paymaster_RejectsEoaMemberBindingMismatch() external {
    address _other = makeAddr('otherMember');
    PackedUserOperation memory _userOp = _buildUserOp(_member, _other, address(0));

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(
      abi.encodeWithSelector(PactoSponsorPaymaster.PactoSponsorPaymaster_InvalidMemberBinding.selector, _member, _other)
    );
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_RejectsInvalidVersion() external {
    bytes memory _payload = abi.encode(uint8(99), _squadId, _vault, _ext, address(0), _member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    PackedUserOperation memory _userOp;
    _userOp.sender = _member;
    _userOp.paymasterAndData = bytes.concat(_header, _payload);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(
      abi.encodeWithSelector(PactoSponsorPaymaster.PactoSponsorPaymaster_InvalidVersion.selector, uint8(99))
    );
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_ValidatesSmartAccountMember() external {
    MockSmartAccount _smartAccount = new MockSmartAccount();
    SquadSponsorExt(_ext).setPermittedAddress(_member, true);

    PackedUserOperation memory _userOp = _buildUserOp(address(_smartAccount), _member, address(0));

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, 0);
  }

  function test_Unit_Paymaster_PostOpSkipsOnRevert() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member, address(0));

    vm.prank(_ENTRY_POINT);
    (bytes memory _context,) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    vm.prank(_ENTRY_POINT);
    _paymaster.postOp(IPaymaster.PostOpMode.opReverted, _context, 1 ether, 0);

    assertEq(address(_vault).balance, 5 ether);
  }

  function test_Unit_Paymaster_ConstructorRevertsZeroFactory() external {
    vm.expectRevert(PactoSponsorPaymaster.PactoSponsorPaymaster_ZeroFactory.selector);
    new PactoSponsorPaymaster(IEntryPoint(_ENTRY_POINT), ISquadSponsorFactory(address(0)));
  }

  function _buildUserOp(
    address sender,
    address member,
    address base
  ) internal view returns (PackedUserOperation memory userOp) {
    bytes memory _payload = abi.encode(uint8(_paymaster.PAYMASTER_DATA_VERSION()), _squadId, _vault, _ext, base, member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    userOp.sender = sender;
    userOp.paymasterAndData = bytes.concat(_header, _payload);
  }

  function _buildUserOpWithVault(
    address sender,
    address member,
    address base,
    address vault,
    address ext
  ) internal view returns (PackedUserOperation memory userOp) {
    bytes memory _payload = abi.encode(uint8(_paymaster.PAYMASTER_DATA_VERSION()), _squadId, vault, ext, base, member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    userOp.sender = sender;
    userOp.paymasterAndData = bytes.concat(_header, _payload);
  }
}
