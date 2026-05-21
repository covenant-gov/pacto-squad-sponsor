// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';
import {RejectEthReceiver} from 'test/unit/helpers/TestHelpers.sol';

/**
 * @title UnitSquadSponsorPool
 * @author Pacto
 * @notice Unit tests for pro-rata pool accounting and paymaster spend on sponsor clones.
 */
contract UnitSquadSponsorPool is UnitSquadSponsorBase {
  ISquadSponsorBase internal _pool;

  address internal _alice = makeAddr('alice');
  address internal _bob = makeAddr('bob');

  function setUp() public override {
    super.setUp();
    address _sponsor = _factory.createSquadSponsorExt(_squadId);
    _pool = ISquadSponsorBase(_sponsor);

    vm.deal(address(this), 10 ether);
    _pool.deposit{value: 10 ether}();
  }

  function test_Unit_Pool_FirstDepositMintsOneToOneShares() external {
    vm.deal(_alice, 5 ether);
    vm.prank(_alice);
    _pool.deposit{value: 5 ether}();

    assertEq(_pool.sponsorShares(_alice), 5 ether);
    assertEq(_pool.totalShares(), 15 ether);
    assertEq(_pool.withdrawable(_alice), 5 ether);
  }

  function test_Unit_Pool_ProRataSecondDepositor() external {
    vm.deal(_alice, 5 ether);
    vm.deal(_bob, 5 ether);

    vm.prank(_alice);
    _pool.deposit{value: 5 ether}();

    vm.prank(_bob);
    _pool.deposit{value: 5 ether}();

    assertEq(_pool.withdrawable(_alice), 5 ether);
    assertEq(_pool.withdrawable(_bob), 5 ether);
  }

  function test_Unit_Pool_WithdrawReturnsProRataShare() external {
    vm.deal(_alice, 5 ether);
    vm.prank(_alice);
    _pool.deposit{value: 5 ether}();

    uint256 _balanceBefore = _alice.balance;
    vm.prank(_alice);
    _pool.withdraw();

    assertEq(_alice.balance - _balanceBefore, 5 ether);
    assertEq(_pool.sponsorShares(_alice), 0);
    assertEq(address(_pool).balance, 10 ether);
  }

  function test_Unit_Pool_SpendGasOnlyPaymaster() external {
    vm.prank(address(_paymaster));
    _pool.spendGas(1 ether);

    assertEq(address(_pool).balance, 9 ether);
    assertEq(address(_paymaster).balance, 1 ether);
  }

  function test_Unit_Pool_SpendGasRevertsForNonPaymaster() external {
    vm.expectRevert(ISquadSponsorBase.SquadSponsorBase_NotPaymaster.selector);
    _pool.spendGas(1 ether);
  }

  function test_Unit_Pool_SpendGasReducesWithdrawableProRata() external {
    vm.deal(_alice, 10 ether);
    vm.prank(_alice);
    _pool.deposit{value: 10 ether}();

    vm.prank(address(_paymaster));
    _pool.spendGas(5 ether);

    assertEq(_pool.withdrawable(_alice), 7.5 ether);
  }

  function test_Unit_Pool_PostInitializeSetsTopHatId() external {
    uint256 _topHatId = 0x100;
    uint256[] memory _customHats = new uint256[](0);

    SquadSponsorExt(payable(address(_pool))).postInitialize(_topHatId, address(0), _customHats);

    assertEq(SquadSponsorExt(payable(address(_pool))).topHatId(), _topHatId);
    assertTrue(SquadSponsorExt(payable(address(_pool))).hatsWired());
  }

  function test_Unit_Pool_PlainSendCreditsShares() external {
    vm.deal(_alice, 2 ether);
    vm.prank(_alice);
    (bool _ok,) = address(_pool).call{value: 2 ether}('');
    assertTrue(_ok);

    assertEq(_pool.sponsorShares(_alice), 2 ether);
    assertEq(_pool.withdrawable(_alice), 2 ether);
  }

  function testFuzz_Unit_Pool_WithdrawableNeverExceedsBalance(address sponsor, uint256 extraDeposit) external {
    extraDeposit = bound(extraDeposit, 1 wei, 100 ether);
    vm.deal(sponsor, extraDeposit);

    vm.prank(sponsor);
    _pool.deposit{value: extraDeposit}();

    uint256 _spent = bound(extraDeposit, 0, address(_pool).balance);
    vm.prank(address(_paymaster));
    _pool.spendGas(_spent);

    assertLe(_pool.withdrawable(sponsor), address(_pool).balance);
  }

  function test_Unit_Pool_DepositForCreditsSponsor() external {
    vm.deal(address(this), 2 ether);
    _pool.depositFor{value: 2 ether}(_alice);

    assertEq(_pool.sponsorShares(_alice), 2 ether);
  }

  function test_Unit_Pool_DepositForZeroAddressReverts() external {
    vm.deal(address(this), 1 ether);
    vm.expectRevert(ISquadSponsorBase.SquadSponsorBase_ZeroAddress.selector);
    _pool.depositFor{value: 1 ether}(address(0));
  }

  function test_Unit_Pool_DepositZeroAmountReverts() external {
    vm.expectRevert(ISquadSponsorBase.SquadSponsorBase_ZeroAmount.selector);
    _pool.deposit();
  }

  function test_Unit_Pool_WithdrawNoSharesReverts() external {
    vm.prank(_alice);
    vm.expectRevert(ISquadSponsorBase.SquadSponsorBase_NoShares.selector);
    _pool.withdraw();
  }

  function test_Unit_Pool_SpendGasInsufficientBalanceReverts() external {
    vm.prank(address(_paymaster));
    vm.expectRevert(ISquadSponsorBase.SquadSponsorBase_InsufficientBalance.selector);
    _pool.spendGas(11 ether);
  }

  function test_Unit_Pool_WithdrawableZeroForNoShares() external view {
    assertEq(_pool.withdrawable(_alice), 0);
  }

  function test_Unit_Pool_FallbackCreditsShares() external {
    vm.deal(_alice, 2 ether);
    vm.prank(_alice);
    (bool _ok,) = address(_pool).call{value: 2 ether}(hex'01');
    assertTrue(_ok);

    assertEq(_pool.sponsorShares(_alice), 2 ether);
  }

  function test_Unit_Pool_WithdrawableZeroEmptyPool() external {
    bytes32 _emptyId = keccak256('empty-pool');
    address _emptySponsor = _factory.createSquadSponsorExt(_emptyId);

    assertEq(ISquadSponsorBase(_emptySponsor).withdrawable(_alice), 0);
  }

  function test_Unit_Pool_DepositAfterFullDrainMintsOneToOne() external {
    vm.deal(_alice, 5 ether);
    vm.prank(_alice);
    _pool.deposit{value: 5 ether}();

    vm.prank(address(_paymaster));
    _pool.spendGas(15 ether);

    vm.deal(address(this), 2 ether);
    _pool.depositFor{value: 2 ether}(_bob);

    assertEq(_pool.sponsorShares(_bob), 2 ether);
  }

  function test_Unit_Pool_WithdrawTransferFailedReverts() external {
    RejectEthReceiver _receiver = new RejectEthReceiver();
    vm.deal(address(this), 1 ether);
    _pool.depositFor{value: 1 ether}(address(_receiver));

    vm.prank(address(_receiver));
    vm.expectRevert(ISquadSponsorBase.SquadSponsorBase_TransferFailed.selector);
    _pool.withdraw();
  }
}
