// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSimple7702Account} from 'contracts/PactoSimple7702Account.sol';
import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';
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
 * @notice Unit tests for paymaster validation and sponsor billing.
 */
contract UnitPactoSponsorPaymaster is UnitSquadSponsorBase {
  address internal _member = makeAddr('member');
  address internal _sponsor;

  function setUp() public override {
    super.setUp();
    vm.deal(_member, 10 ether);
    vm.deal(address(this), 5 ether);
    _sponsor = _factory.createSquadSponsorExt{value: 5 ether}(_squadId, address(this));
    SquadSponsorExt(payable(_sponsor)).setPermittedAddress(_member, true);
  }

  function test_Unit_Paymaster_ValidatesExtEligibility() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    (bytes memory _context, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, 0);
    assertEq(_context, abi.encode(address(_poolOf(_sponsor))));
  }

  function test_Unit_Paymaster_RejectsIneligibleMember() external {
    address _outsider = makeAddr('outsider');
    PackedUserOperation memory _userOp = _buildUserOp(_outsider, _outsider);

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_Paymaster_PostOpSpendsFromSponsor() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    (bytes memory _context,) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    uint256 _balanceBefore = address(_paymaster).balance;
    vm.prank(_ENTRY_POINT);
    _paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, _context, 1 ether, 0);

    assertEq(address(_poolOf(_sponsor)).balance, 4 ether);
    assertEq(_poolOf(_sponsor).spendablePoolWei(), 4 ether);
    assertEq(address(_paymaster).balance - _balanceBefore, 1 ether);
  }

  function test_Unit_Paymaster_RoutesToHatEligibilityWhenWired() external {
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = 0xBEEF;

    SquadSponsorExt(payable(_sponsor)).postInitialize(0x100, address(0), _customHats);

    _mockHatWearer(_member, 0xBEEF, true);

    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, 0);
  }

  function test_Unit_Paymaster_RejectsInsufficientSponsorBalance() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 5 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_Paymaster_RejectsCloneMismatchWrongSponsor() external {
    address _wrongSponsor = makeAddr('wrongSponsor');
    PackedUserOperation memory _userOp = _buildUserOpWithSponsor(_member, _member, _wrongSponsor);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_CloneMismatch.selector, _squadId));
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_RejectsZeroMember() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, address(0));

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_Paymaster_RejectsEoaMemberBindingMismatch() external {
    address _other = makeAddr('otherMember');
    PackedUserOperation memory _userOp = _buildUserOp(_member, _other);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_InvalidMemberBinding.selector, _member, _other));
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_RejectsInvalidVersion() external {
    bytes memory _payload = abi.encode(uint8(99), _squadId, _sponsor, _member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    PackedUserOperation memory _userOp;
    _userOp.sender = _member;
    _userOp.paymasterAndData = bytes.concat(_header, _payload);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_InvalidVersion.selector, uint8(99)));
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_ValidatesSmartAccountMember() external {
    MockSmartAccount _smartAccount = new MockSmartAccount();
    SquadSponsorExt(payable(_sponsor)).setPermittedAddress(_member, true);

    PackedUserOperation memory _userOp = _buildUserOp(address(_smartAccount), _member);

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, 0);
  }

  function test_Unit_Paymaster_Validates7702SenderWithAllowlistedImpl() external {
    PactoSimple7702Account _accountImpl = new PactoSimple7702Account();
    _redeployFactoryWith7702(address(_accountImpl));

    _sponsor = _factory.createSquadSponsorExt{value: 5 ether}(_squadId, address(this));
    SquadSponsorExt(payable(_sponsor)).setPermittedAddress(_member, true);

    vm.etch(_member, abi.encodePacked(bytes3(0xef0100), address(_accountImpl)));

    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    (, uint256 _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    assertEq(_validationData, 0);
    assertEq(_paymaster.ALLOWED_7702_IMPLEMENTATION(), address(_accountImpl));
  }

  function test_Unit_Paymaster_Rejects7702WrongImplementation() external {
    PactoSimple7702Account _allowed = new PactoSimple7702Account();
    PactoSimple7702Account _other = new PactoSimple7702Account();
    _redeployFactoryWith7702(address(_allowed));

    _sponsor = _factory.createSquadSponsorExt{value: 5 ether}(_squadId, address(this));
    SquadSponsorExt(payable(_sponsor)).setPermittedAddress(_member, true);

    vm.etch(_member, abi.encodePacked(bytes3(0xef0100), address(_other)));

    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_Invalid7702Implementation.selector, address(_other)));
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_Rejects7702WhenAllowlistUnset() external {
    // Default fixture: ALLOWED_7702_IMPLEMENTATION == address(0)
    PactoSimple7702Account _accountImpl = new PactoSimple7702Account();
    vm.etch(_member, abi.encodePacked(bytes3(0xef0100), address(_accountImpl)));

    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(
      abi.encodeWithSelector(ISquadSponsorCommon.SS_Invalid7702Implementation.selector, address(_accountImpl))
    );
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_Rejects7702MemberBindingMismatch() external {
    PactoSimple7702Account _accountImpl = new PactoSimple7702Account();
    _redeployFactoryWith7702(address(_accountImpl));

    _sponsor = _factory.createSquadSponsorExt{value: 5 ether}(_squadId, address(this));
    address _other = makeAddr('otherMember');
    SquadSponsorExt(payable(_sponsor)).setPermittedAddress(_other, true);

    vm.etch(_member, abi.encodePacked(bytes3(0xef0100), address(_accountImpl)));

    PackedUserOperation memory _userOp = _buildUserOp(_member, _other);

    vm.prank(_ENTRY_POINT);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_InvalidMemberBinding.selector, _member, _other));
    _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_PostOpSkipsOnRevert() external {
    PackedUserOperation memory _userOp = _buildUserOp(_member, _member);

    vm.prank(_ENTRY_POINT);
    (bytes memory _context,) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), 1 ether);

    vm.prank(_ENTRY_POINT);
    _paymaster.postOp(IPaymaster.PostOpMode.opReverted, _context, 1 ether, 0);

    assertEq(address(_poolOf(_sponsor)).balance, 5 ether);
  }

  function test_Unit_Paymaster_ValidatesWarGameSquadIdWhileParentHatsWired() external {
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = 0xC001;
    SquadSponsorExt(payable(_sponsor)).postInitialize(0x100, address(0), _customHats);

    vm.deal(address(this), 5 ether);
    (address _gameSponsor,, bytes32 _gameSquadId) =
      _factory.createWarGameSponsorExt{value: 5 ether}(_squadId, address(this));
    address _gameMember = makeAddr('warGameMember');
    SquadSponsorExt(payable(_gameSponsor)).setPermittedAddress(_gameMember, true);

    PackedUserOperation memory _gameOp = _buildUserOpFor(_gameMember, _gameSquadId, _gameSponsor, _gameMember);
    vm.prank(_ENTRY_POINT);
    (, uint256 _gameValidation) = _paymaster.validatePaymasterUserOp(_gameOp, bytes32(0), 1 ether);
    assertEq(_gameValidation, 0);

    PackedUserOperation memory _parentOp = _buildUserOp(_gameMember, _gameMember);
    vm.prank(_ENTRY_POINT);
    (, uint256 _parentValidation) = _paymaster.validatePaymasterUserOp(_parentOp, bytes32(0), 1 ether);
    assertEq(_parentValidation, SIG_VALIDATION_FAILED);
  }

  function test_Unit_Paymaster_RejectsUnslottedPreviousWarGameRound() external {
    vm.deal(address(this), 5 ether);
    (address _first,, bytes32 _firstId) = _factory.createWarGameSponsorExt{value: 5 ether}(_squadId, address(this));
    address _firstMember = makeAddr('firstRoundMember');
    SquadSponsorExt(payable(_first)).setPermittedAddress(_firstMember, true);

    (address _second,,) = _factory.createWarGameSponsorExt(_squadId, address(this));
    assertEq(_poolOf(_second).wargame(), _second);

    PackedUserOperation memory _staleOp = _buildUserOpFor(_firstMember, _firstId, _first, _firstMember);
    vm.prank(_ENTRY_POINT);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_SponsorNotInPoolSlot.selector, _first));
    _paymaster.validatePaymasterUserOp(_staleOp, bytes32(0), 1 ether);
  }

  function test_Unit_Paymaster_ConstructorRevertsZeroFactory() external {
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    new PactoSponsorPaymaster(IEntryPoint(_ENTRY_POINT), ISquadSponsorFactory(address(0)), address(0));
  }

  function _buildUserOp(address sender, address member) internal view returns (PackedUserOperation memory userOp) {
    bytes memory _payload = abi.encode(uint8(_paymaster.PAYMASTER_DATA_VERSION()), _squadId, _sponsor, member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    userOp.sender = sender;
    userOp.paymasterAndData = bytes.concat(_header, _payload);
  }

  function _buildUserOpWithSponsor(
    address sender,
    address member,
    address sponsor
  ) internal view returns (PackedUserOperation memory userOp) {
    userOp = _buildUserOpFor(sender, _squadId, sponsor, member);
  }

  function _buildUserOpFor(
    address sender,
    bytes32 squadId,
    address sponsor,
    address member
  ) internal view returns (PackedUserOperation memory userOp) {
    bytes memory _payload = abi.encode(uint8(_paymaster.PAYMASTER_DATA_VERSION()), squadId, sponsor, member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    userOp.sender = sender;
    userOp.paymasterAndData = bytes.concat(_header, _payload);
  }

  function _redeployFactoryWith7702(address allowed7702) internal {
    _factory = new SquadSponsorFactory(IEntryPoint(_ENTRY_POINT), allowed7702);
    _paymaster = PactoSponsorPaymaster(payable(_factory.PAYMASTER()));
    vm.deal(address(this), 5 ether);
  }
}
