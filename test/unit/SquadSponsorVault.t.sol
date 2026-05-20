// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorVault} from 'contracts/SquadSponsorVault.sol';

import {ISquadSponsorVault} from 'interfaces/ISquadSponsorVault.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitSquadSponsorVault
 * @author Pacto
 * @notice Unit tests for pro-rata vault accounting and paymaster spend.
 */
contract UnitSquadSponsorVault is UnitSquadSponsorBase {
  SquadSponsorVault internal _vault;
  address internal _ext;

  address internal _alice = makeAddr('alice');
  address internal _bob = makeAddr('bob');

  function setUp() public override {
    super.setUp();
    (address _vaultAddr, address _extAddr) = _factory.createSquad(_squadId);
    _vault = SquadSponsorVault(payable(_vaultAddr));
    _ext = _extAddr;

    vm.deal(address(this), 10 ether);
    _vault.deposit{value: 10 ether}();
  }

  function test_Unit_Vault_FirstDepositMintsOneToOneShares() external {
    vm.deal(_alice, 5 ether);
    vm.prank(_alice);
    _vault.deposit{value: 5 ether}();

    assertEq(_vault.sponsorShares(_alice), 5 ether);
    assertEq(_vault.totalShares(), 15 ether);
    assertEq(_vault.withdrawable(_alice), 5 ether);
  }

  function test_Unit_Vault_ProRataSecondDepositor() external {
    vm.deal(_alice, 5 ether);
    vm.deal(_bob, 5 ether);

    vm.prank(_alice);
    _vault.deposit{value: 5 ether}();

    vm.prank(_bob);
    _vault.deposit{value: 5 ether}();

    assertEq(_vault.withdrawable(_alice), 5 ether);
    assertEq(_vault.withdrawable(_bob), 5 ether);
  }

  function test_Unit_Vault_WithdrawReturnsProRataShare() external {
    vm.deal(_alice, 5 ether);
    vm.prank(_alice);
    _vault.deposit{value: 5 ether}();

    uint256 _balanceBefore = _alice.balance;
    vm.prank(_alice);
    _vault.withdraw();

    assertEq(_alice.balance - _balanceBefore, 5 ether);
    assertEq(_vault.sponsorShares(_alice), 0);
    assertEq(address(_vault).balance, 10 ether);
  }

  function test_Unit_Vault_SpendGasOnlyPaymaster() external {
    vm.prank(address(_paymaster));
    _vault.spendGas(1 ether);

    assertEq(address(_vault).balance, 9 ether);
    assertEq(address(_paymaster).balance, 1 ether);
  }

  function test_Unit_Vault_SpendGasRevertsForNonPaymaster() external {
    vm.expectRevert(ISquadSponsorVault.SquadSponsorVault_NotPaymaster.selector);
    _vault.spendGas(1 ether);
  }

  function test_Unit_Vault_SpendGasReducesWithdrawableProRata() external {
    vm.deal(_alice, 10 ether);
    vm.prank(_alice);
    _vault.deposit{value: 10 ether}();

    vm.prank(address(_paymaster));
    _vault.spendGas(5 ether);

    assertEq(_vault.withdrawable(_alice), 7.5 ether);
  }

  function test_Unit_Vault_LinkTopHatOnlyExt() external {
    uint256 _topHatId = 0x100;

    vm.prank(_ext);
    _vault.linkTopHat(_topHatId);

    assertEq(_vault.topHatId(), _topHatId);

    vm.expectRevert(ISquadSponsorVault.SquadSponsorVault_NotExt.selector);
    _vault.linkTopHat(_topHatId + 1);
  }

  function test_Unit_Vault_PlainSendCreditsShares() external {
    vm.deal(_alice, 2 ether);
    vm.prank(_alice);
    (bool _ok,) = address(_vault).call{value: 2 ether}('');
    assertTrue(_ok);

    assertEq(_vault.sponsorShares(_alice), 2 ether);
    assertEq(_vault.withdrawable(_alice), 2 ether);
  }

  function testFuzz_Unit_Vault_WithdrawableNeverExceedsBalance(address sponsor, uint256 extraDeposit) external {
    extraDeposit = bound(extraDeposit, 1 wei, 100 ether);
    vm.deal(sponsor, extraDeposit);

    vm.prank(sponsor);
    _vault.deposit{value: extraDeposit}();

    uint256 _spent = bound(extraDeposit, 0, address(_vault).balance);
    vm.prank(address(_paymaster));
    _vault.spendGas(_spent);

    assertLe(_vault.withdrawable(sponsor), address(_vault).balance);
  }
}
