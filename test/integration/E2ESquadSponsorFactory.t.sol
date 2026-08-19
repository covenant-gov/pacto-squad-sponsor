// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {Constants} from 'script/Constants.sol';

import {Vm} from 'forge-std/Vm.sol';
import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

/**
 * @title E2ESquadSponsorFactoryTest
 * @author Pacto
 * @notice End-to-end scenarios for `SquadSponsorFactory`; inherits `IntegrationBase` (mainnet fork required).
 */
contract E2ESquadSponsorFactoryTest is IntegrationBase {
  address internal _creator = makeAddr('e2eFactoryCreator');
  address internal _rosterOwner = makeAddr('e2eRosterOwner');

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
    address _sponsor = _factory.createSquadSponsorExt(_id, _creator);

    assertGt(_sponsor.code.length, 0);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_id);
    assertEq(_record.sponsor, _sponsor);
    assertEq(uint256(_record.variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
    assertEq(_record.topHatId, 0);
    assertEq(_factory.squadIdBySponsor(_sponsor), _id);
  }

  function test_e2e_createSquadSponsorExt_setsConfiguredAddressOwner() public {
    bytes32 _id = _freshSquadId();
    _fund(_creator, 1 ether);

    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_id, _rosterOwner);

    assertEq(SquadSponsorExt(payable(_sponsor)).addressOwner(), _rosterOwner);
    assertTrue(_creator != _rosterOwner);
  }

  function test_e2e_createSquadSponsorExt_deployerNotOwner_cannotSetPermitted() public {
    bytes32 _id = _freshSquadId();
    address _member = makeAddr('e2ePermittedByOwner');
    _fund(_creator, 1 ether);

    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_id, _rosterOwner);
    SquadSponsorExt _ext = SquadSponsorExt(payable(_sponsor));

    vm.prank(_creator);
    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    _ext.setPermittedAddress(_member, true);

    vm.prank(_rosterOwner);
    _ext.setPermittedAddress(_member, true);
    assertTrue(_ext.isEligible(_member));
  }

  function test_e2e_createSquadSponsorExt_withDepositCreditsFunderShares() public {
    bytes32 _id = _freshSquadId();
    _fund(_creator, 3 ether);

    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt{value: 3 ether}(_id, _rosterOwner);

    assertEq(address(_sponsor).balance, 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_creator), 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_rosterOwner), 0);
  }

  function test_e2e_createSquadSponsorExt_revertsOnZeroAddressOwner() public {
    bytes32 _id = _freshSquadId();

    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    _factory.createSquadSponsorExt(_id, address(0));
  }

  function test_e2e_createSquadSponsorExt_emitsConfiguredAddressOwner() public {
    bytes32 _id = _freshSquadId();
    _fund(_creator, 1 ether);

    vm.recordLogs();
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_id, _rosterOwner);

    Vm.Log[] memory _logs = vm.getRecordedLogs();
    bool _found;
    for (uint256 _i; _i < _logs.length; ++_i) {
      if (_logs[_i].topics[0] != ISquadSponsorCommon.SquadCreated.selector) continue;
      assertEq(_logs[_i].topics[1], _id);
      assertEq(address(uint160(uint256(_logs[_i].topics[2]))), _rosterOwner);
      (address _emittedSponsor, ISquadSponsorCommon.SquadVariant _variant) =
        abi.decode(_logs[_i].data, (address, ISquadSponsorCommon.SquadVariant));
      assertEq(_emittedSponsor, _sponsor);
      assertEq(uint256(_variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
      _found = true;
    }
    assertTrue(_found);
  }

  function test_e2e_createSquadSponsorExt_revertsWhenSquadAlreadyExists() public withDeployedExtSquad {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_SquadAlreadyExists.selector, _squadId));
    _factory.createSquadSponsorExt(_squadId, _addressOwner);
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
                        createWarGameSponsorExt
  //////////////////////////////////////////////////////////////*/

  function test_e2e_createWarGameSponsorExt_deploysCloneWithoutRegisteringParent() public {
    bytes32 _parentId = _freshSquadId();
    _fund(_creator, 1 ether);

    vm.prank(_creator);
    (address _sponsor, uint256 _round, bytes32 _gameSquadId) = _factory.createWarGameSponsorExt(_parentId, _rosterOwner);

    assertEq(_round, 1);
    assertEq(_gameSquadId, _factory.warGameSquadId(_parentId, 1));
    assertEq(_sponsor, _factory.predictWarGameSponsor(_parentId, 1));
    assertGt(_sponsor.code.length, 0);
    assertEq(_factory.squads(_gameSquadId).sponsor, _sponsor);
    assertEq(_factory.squads(_parentId).sponsor, address(0));
    assertEq(uint256(_factory.squads(_gameSquadId).variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
  }

  function test_e2e_createWarGameSponsorExt_twoRoundsIsolatedFromParent() public {
    bytes32 _parentId = _freshSquadId();
    _fund(_creator, 2 ether);

    vm.prank(_creator);
    address _parent = _factory.createSquadSponsorExt(_parentId, _creator);

    vm.startPrank(_rosterOwner);
    vm.deal(_rosterOwner, 1 ether);
    (address _first, uint256 _round1, bytes32 _id1) = _factory.createWarGameSponsorExt(_parentId, _rosterOwner);
    (address _second, uint256 _round2, bytes32 _id2) = _factory.createWarGameSponsorExt(_parentId, _rosterOwner);

    uint256[] memory _customHats = new uint256[](0);
    SquadSponsorExt(payable(_first)).postInitialize(_E2E_TOP_HAT_ID, address(0), _customHats);
    vm.stopPrank();

    assertEq(_round1, 1);
    assertEq(_round2, 2);
    assertTrue(_first != _second);
    assertTrue(_first != _parent);
    assertEq(_factory.squads(_parentId).sponsor, _parent);
    assertEq(_factory.squads(_id1).topHatId, _E2E_TOP_HAT_ID);
    assertEq(_factory.squads(_id2).topHatId, 0);
    assertFalse(SquadSponsorExt(payable(_second)).hatsWired());
    assertFalse(SquadSponsorExt(payable(_parent)).hatsWired());
  }

  function test_e2e_createWarGameSponsorExt_withDepositCreditsFunderShares() public {
    bytes32 _parentId = _freshSquadId();
    _fund(_creator, 3 ether);

    vm.prank(_creator);
    (address _sponsor,,) = _factory.createWarGameSponsorExt{value: 3 ether}(_parentId, _rosterOwner);

    assertEq(address(_sponsor).balance, 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_creator), 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_rosterOwner), 0);
  }

  function test_e2e_createWarGameSponsorExt_revertsOnZeroParent() public {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_ZeroField.selector, 'parentSquadId'));
    _factory.createWarGameSponsorExt(bytes32(0), _rosterOwner);
  }

  /*///////////////////////////////////////////////////////////////
                        constructor
  //////////////////////////////////////////////////////////////*/

  function test_e2e_factoryConstructor_revertsOnZeroEntryPoint() public {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_ZeroField.selector, 'entryPoint'));
    new SquadSponsorFactory(IEntryPoint(address(0)), address(0));
  }
}
