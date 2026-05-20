// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorVault} from 'contracts/SquadSponsorVault.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitSquadSponsorFactory
 * @author Pacto
 * @notice Unit tests for squad clone deployment and registry.
 */
contract UnitSquadSponsorFactory is UnitSquadSponsorBase {
  address internal _creator = makeAddr('creator');

  function test_Unit_Factory_CreateSquadDeploysClones() external {
    vm.prank(_creator);
    (address _vault, address _ext) = _factory.createSquad(_squadId);

    assertTrue(_vault.code.length > 0);
    assertTrue(_ext.code.length > 0);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.vault, _vault);
    assertEq(_record.ext, _ext);
    assertEq(_factory.squadIdByVault(_vault), _squadId);
    assertEq(_factory.squadIdByExt(_ext), _squadId);
  }

  function test_Unit_Factory_FirstDepositorBecomesAddressOwner() external {
    vm.prank(_creator);
    (, address _ext) = _factory.createSquad(_squadId);

    assertEq(SquadSponsorExt(_ext).addressOwner(), _creator);
  }

  function test_Unit_Factory_CreateWithDepositFundsVault() external {
    vm.deal(_creator, 3 ether);
    vm.prank(_creator);
    (address _vault,) = _factory.createSquad{value: 3 ether}(_squadId);

    assertEq(address(_vault).balance, 3 ether);
    assertEq(SquadSponsorVault(payable(_vault)).sponsorShares(_creator), 3 ether);
  }

  function test_Unit_Factory_DuplicateSquadReverts() external {
    _createSquad(_squadId, 0);

    vm.expectRevert(
      abi.encodeWithSelector(ISquadSponsorFactory.SquadSponsorFactory_SquadAlreadyExists.selector, _squadId)
    );
    _factory.createSquad(_squadId);
  }

  function test_Unit_Factory_RegistryAfterHatsWiring() external {
    vm.deal(_creator, 1 ether);
    vm.prank(_creator);
    (address _vault, address _ext) = _factory.createSquad{value: 1 ether}(_squadId);

    uint256 _topHatId = 0x200;
    address _base = makeAddr('squadSponsorBase');

    vm.prank(_creator);
    SquadSponsorExt(_ext).postInitialize(_topHatId, _base);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.base, _base);
    assertEq(_record.topHatId, _topHatId);
    assertEq(SquadSponsorVault(payable(_vault)).topHatId(), _topHatId);
  }
}
