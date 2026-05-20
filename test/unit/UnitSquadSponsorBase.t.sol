// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorVault} from 'contracts/SquadSponsorVault.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/// @notice Exercises shared base helpers for coverage.
contract UnitSquadSponsorBase_Test is UnitSquadSponsorBase {
  function test_Unit_Base_CreateSquadWithoutDeposit() external {
    (address vault, address ext) = _createSquad(keccak256('base-no-deposit'));

    assertTrue(vault.code.length > 0);
    assertTrue(ext.code.length > 0);
  }

  function test_Unit_Base_CreateSquadWithDeposit() external {
    vm.deal(address(this), 2 ether);
    (address vault,) = _createSquadWithDeposit(keccak256('base-with-deposit'), 2 ether);

    assertEq(address(vault).balance, 2 ether);
    assertEq(SquadSponsorVault(payable(vault)).sponsorShares(address(this)), 2 ether);
  }
}
