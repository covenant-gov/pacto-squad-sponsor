// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {Constants} from 'script/Constants.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

/**
 * @title E2ESquadSponsorFactoryTest
 * @author Pacto
 * @notice End-to-end scenarios for `SquadSponsorFactory`; inherits `IntegrationBase` (mainnet fork required).
 */
contract E2ESquadSponsorFactoryTest is IntegrationBase {
  address internal _creator = makeAddr('e2eFactoryCreator');

  /*///////////////////////////////////////////////////////////////
                        integration wiring
  //////////////////////////////////////////////////////////////*/

  function test_integration_factoryAndPaymasterDeployed() public view {
    assertGt(address(_factory).code.length, 0);
    assertGt(address(_paymaster).code.length, 0);
    assertEq(_factory.PAYMASTER(), address(_paymaster));
    assertEq(_factory.hats(), Constants.hats());
    assertGt(_factory.sponsorImplementation().code.length, 0);
    assertGt(_factory.extImplementation().code.length, 0);
  }

  function test_integration_create2DeployMatchesPredictedAddresses() public view {
    assertEq(address(_factory), _deployAddrs.factory);
    assertEq(address(_paymaster), _deployAddrs.paymaster);
    assertEq(_factory.PAYMASTER(), address(_paymaster));
  }

  /*///////////////////////////////////////////////////////////////
                        createSquadSponsorExt
  //////////////////////////////////////////////////////////////*/

  function test_e2e_createSquadSponsorExt_deploysCloneAndRegisters() public {
    bytes32 _id = _freshSquadId();
    _fund(_creator, 1 ether);

    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_id);

    assertGt(_sponsor.code.length, 0);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_id);
    assertEq(_record.sponsor, _sponsor);
    assertEq(uint256(_record.variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
    assertEq(_record.topHatId, 0);
    assertEq(_factory.squadIdBySponsor(_sponsor), _id);
  }

  function test_e2e_createSquadSponsorExt_firstCallerBecomesAddressOwner() public {
    bytes32 _id = _freshSquadId();

    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_id);

    assertEq(SquadSponsorExt(payable(_sponsor)).addressOwner(), _creator);
  }

  function test_e2e_createSquadSponsorExt_withDepositCreditsShares() public {
    bytes32 _id = _freshSquadId();
    _fund(_creator, 3 ether);

    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt{value: 3 ether}(_id);

    assertEq(address(_sponsor).balance, 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_creator), 3 ether);
  }

  function test_e2e_createSquadSponsorExt_revertsWhenSquadAlreadyExists() public withDeployedExtSquad {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_SquadAlreadyExists.selector, _squadId));
    _factory.createSquadSponsorExt(_squadId);
  }

  /*///////////////////////////////////////////////////////////////
                        createSquadSponsor
  //////////////////////////////////////////////////////////////*/

  function test_e2e_createSquadSponsor_deploysHatCloneAndRegisters() public {
    bytes32 _id = _freshSquadId();
    uint256[] memory _customHats = new uint256[](0);

    address _sponsor = _factory.createSquadSponsor(_id, _E2E_TOP_HAT_ID, address(0), _customHats);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_id);
    assertEq(_record.sponsor, _sponsor);
    assertEq(uint256(_record.variant), uint256(ISquadSponsorCommon.SquadVariant.SPONSOR));
    assertEq(_record.topHatId, _E2E_TOP_HAT_ID);
  }

  function test_e2e_createSquadSponsor_revertsWhenSquadAlreadyExists() public withDeployedHatSponsor {
    uint256[] memory _customHats = new uint256[](0);

    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_SquadAlreadyExists.selector, _hatSquadId));
    _factory.createSquadSponsor(_hatSquadId, _E2E_TOP_HAT_ID + 1, address(0), _customHats);
  }

  /*///////////////////////////////////////////////////////////////
                        registerHatsWiring
  //////////////////////////////////////////////////////////////*/

  function test_e2e_registerHatsWiring_updatesRegistryWhenCalledBySponsor() public withDeployedExtSquad {
    vm.prank(address(_extSponsor));
    _factory.registerHatsWiring(_squadId, _E2E_TOP_HAT_ID);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.topHatId, _E2E_TOP_HAT_ID);
  }

  function test_e2e_registerHatsWiring_revertsWhenUnknownSquad() public {
    bytes32 _missing = keccak256('e2e.missing.squad');

    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_UnknownSquad.selector, _missing));
    _factory.registerHatsWiring(_missing, _E2E_TOP_HAT_ID);
  }

  function test_e2e_registerHatsWiring_revertsWhenNotSponsorClone() public withDeployedExtSquad {
    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    vm.prank(_creator);
    _factory.registerHatsWiring(_squadId, _E2E_TOP_HAT_ID);
  }

  /*///////////////////////////////////////////////////////////////
                        constructor
  //////////////////////////////////////////////////////////////*/

  function test_e2e_factoryConstructor_revertsOnZeroEntryPoint() public {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_ZeroField.selector, 'entryPoint'));
    new SquadSponsorFactory(IEntryPoint(address(0)));
  }
}
