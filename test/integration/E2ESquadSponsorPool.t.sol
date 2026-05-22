// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

/**
 * @title E2ESquadSponsorPoolTest
 * @author Pacto
 * @notice End-to-end scenarios for pro-rata pool accounting on forked sponsor clones.
 */
contract E2ESquadSponsorPoolTest is IntegrationBase {
  address internal _alice = makeAddr('e2ePoolAlice');
  address internal _bob = makeAddr('e2ePoolBob');

  /*///////////////////////////////////////////////////////////////
                        deposit / withdraw
  //////////////////////////////////////////////////////////////*/

  function test_e2e_deposit_mintsProRataShares() public withDeployedExtSquad {
    _fund(_alice, 2 ether);

    vm.prank(_alice);
    _pool().deposit{value: 2 ether}();

    assertEq(_pool().sponsorShares(_alice), 2 ether);
    assertEq(_pool().totalShares(), _E2E_POOL_DEPOSIT + 2 ether);
    assertEq(_pool().withdrawable(_alice), 2 ether);
  }

  function test_e2e_depositFor_creditsNamedSponsor() public withDeployedExtSquad {
    _fund(_bob, 1 ether);

    _pool().depositFor{value: 1 ether}(_bob);

    assertEq(_pool().sponsorShares(_bob), 1 ether);
  }

  function test_e2e_withdraw_returnsProRataShare() public withDeployedExtSquad {
    _fund(_alice, 2 ether);
    vm.prank(_alice);
    _pool().deposit{value: 2 ether}();

    uint256 _before = _alice.balance;
    vm.prank(_alice);
    _pool().withdraw();

    assertEq(_alice.balance - _before, 2 ether);
    assertEq(_pool().sponsorShares(_alice), 0);
  }

  function test_e2e_withdraw_revertsWhenNoShares() public withDeployedExtSquad {
    vm.expectRevert(ISquadSponsorCommon.SS_NoShares.selector);
    vm.prank(_stranger);
    _pool().withdraw();
  }

  /*///////////////////////////////////////////////////////////////
                        spendGas
  //////////////////////////////////////////////////////////////*/

  function test_e2e_spendGas_succeedsFromPaymaster() public withDeployedExtSquad {
    uint256 _amount = 1 ether;
    uint256 _paymasterBefore = address(_paymaster).balance;

    vm.prank(address(_paymaster));
    _pool().spendGas(_amount);

    assertEq(address(_extSponsor).balance, _E2E_POOL_DEPOSIT - _amount);
    assertEq(address(_paymaster).balance - _paymasterBefore, _amount);
  }

  function test_e2e_spendGas_revertsWhenNotPaymaster() public withDeployedExtSquad {
    vm.expectRevert(ISquadSponsorCommon.SS_NotPaymaster.selector);
    vm.prank(_stranger);
    _pool().spendGas(1 ether);
  }

  function test_e2e_spendGas_revertsWhenInsufficientBalance() public withDeployedExtSquad {
    vm.expectRevert(ISquadSponsorCommon.SS_InsufficientBalance.selector);
    vm.prank(address(_paymaster));
    _pool().spendGas(_E2E_POOL_DEPOSIT + 1);
  }
}
