// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/// @notice Exercises shared base helpers for coverage.
contract UnitSquadSponsorBase_Test is UnitSquadSponsorBase {
  function test_Unit_Base_CreateSquadExtWithoutDeposit() external {
    address _sponsor = _createSquadExt(keccak256('base-no-deposit'));

    assertTrue(_sponsor.code.length > 0);
  }

  function test_Unit_Base_CreateSquadExtWithDeposit() external {
    vm.deal(address(this), 2 ether);
    address _sponsor = _createSquadExtWithDeposit(keccak256('base-with-deposit'), 2 ether);

    assertEq(address(_sponsor).balance, 2 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(address(this)), 2 ether);
  }
}
