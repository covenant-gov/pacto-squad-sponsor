// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BasePaymaster} from '@account-abstraction/core/BasePaymaster.sol';
import {IStakeManager} from '@account-abstraction/interfaces/IStakeManager.sol';

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitFactoryPaymasterStake
 * @author Pacto
 * @notice Unit tests for FCFS paymaster stake / deposit-withdraw factory forwards.
 */
contract UnitFactoryPaymasterStake is UnitSquadSponsorBase {
  address internal _staker = makeAddr('staker');
  address internal _other = makeAddr('other');
  address payable internal _recipient = payable(makeAddr('recipient'));

  function setUp() public override {
    super.setUp();
    vm.deal(_staker, 10 ether);
    vm.deal(_other, 10 ether);

    // EntryPoint stake/deposit surface used by BasePaymaster forwards.
    vm.mockCall(_ENTRY_POINT, abi.encodeWithSelector(IStakeManager.addStake.selector), abi.encode());
    vm.mockCall(_ENTRY_POINT, abi.encodeWithSelector(IStakeManager.unlockStake.selector), abi.encode());
    vm.mockCall(_ENTRY_POINT, abi.encodeWithSelector(IStakeManager.withdrawStake.selector), abi.encode());
    vm.mockCall(_ENTRY_POINT, abi.encodeWithSelector(IStakeManager.withdrawTo.selector), abi.encode());
  }

  function test_Unit_Factory_AddPaymasterStake_ClaimsVacantSlot() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    assertEq(_factory.paymasterStaker(), _staker);
  }

  function test_Unit_Factory_AddPaymasterStake_SecondWalletReverts() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_other);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_StakeSlotOccupied.selector, _staker));
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);
  }

  function test_Unit_Factory_AddPaymasterStake_StakerCanTopUp() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.01 ether}(1 days);

    assertEq(_factory.paymasterStaker(), _staker);
  }

  function test_Unit_Factory_AddPaymasterStake_InitialTooSmallReverts() external {
    vm.prank(_staker);
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_StakeTooSmall.selector, 0.05 ether, 0.1 ether));
    _factory.addPaymasterStake{value: 0.05 ether}(1 days);
  }

  function test_Unit_Factory_AddPaymasterStake_DelayTooShortReverts() external {
    vm.prank(_staker);
    vm.expectRevert(
      abi.encodeWithSelector(ISquadSponsorCommon.SS_UnstakeDelayTooShort.selector, uint32(12 hours), uint32(1 days))
    );
    _factory.addPaymasterStake{value: 0.1 ether}(12 hours);
  }

  function test_Unit_Factory_AddPaymasterStake_ZeroValueReverts() external {
    vm.prank(_staker);
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAmount.selector);
    _factory.addPaymasterStake{value: 0}(1 days);
  }

  function test_Unit_Factory_UnlockPaymasterStake_OnlyStaker() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_other);
    vm.expectRevert(ISquadSponsorCommon.SS_NotPaymasterStaker.selector);
    _factory.unlockPaymasterStake();

    vm.prank(_staker);
    _factory.unlockPaymasterStake();
  }

  function test_Unit_Factory_WithdrawPaymasterStake_ClearsSlot() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_staker);
    _factory.unlockPaymasterStake();

    vm.prank(_staker);
    _factory.withdrawPaymasterStake(_recipient);

    assertEq(_factory.paymasterStaker(), address(0));

    // Slot vacant again — another wallet can claim.
    vm.prank(_other);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);
    assertEq(_factory.paymasterStaker(), _other);
  }

  function test_Unit_Factory_WithdrawPaymasterStake_NonStakerReverts() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_other);
    vm.expectRevert(ISquadSponsorCommon.SS_NotPaymasterStaker.selector);
    _factory.withdrawPaymasterStake(_recipient);
  }

  function test_Unit_Factory_WithdrawPaymasterStake_ZeroToReverts() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_staker);
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    _factory.withdrawPaymasterStake(payable(address(0)));
  }

  function test_Unit_Factory_WithdrawPaymasterDeposit_OnlyStaker() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_other);
    vm.expectRevert(ISquadSponsorCommon.SS_NotPaymasterStaker.selector);
    _factory.withdrawPaymasterDeposit(_recipient, 1 ether);

    vm.expectCall(address(_paymaster), abi.encodeCall(BasePaymaster.withdrawTo, (_recipient, 1 ether)));
    vm.prank(_staker);
    _factory.withdrawPaymasterDeposit(_recipient, 1 ether);
  }

  function test_Unit_Factory_WithdrawPaymasterDeposit_VacantSlotReverts() external {
    vm.expectRevert(ISquadSponsorCommon.SS_NotPaymasterStaker.selector);
    _factory.withdrawPaymasterDeposit(_recipient, 1 ether);
  }

  function test_Unit_Factory_WithdrawPaymasterDeposit_ZeroAmountReverts() external {
    vm.prank(_staker);
    _factory.addPaymasterStake{value: 0.1 ether}(1 days);

    vm.prank(_staker);
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAmount.selector);
    _factory.withdrawPaymasterDeposit(_recipient, 0);
  }
}
