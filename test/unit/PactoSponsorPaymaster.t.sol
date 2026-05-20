// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorVault} from 'contracts/SquadSponsorVault.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {SIG_VALIDATION_FAILED} from '@account-abstraction/core/Helpers.sol';
import {UserOperationLib} from '@account-abstraction/core/UserOperationLib.sol';
import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

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
    (_vault, _ext) = _factory.createSquad{value: 5 ether}(_squadId);
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
}
