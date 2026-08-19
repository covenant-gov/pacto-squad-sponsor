// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {Vm} from 'forge-std/Vm.sol';
import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitSquadSponsorFactory
 * @author Pacto
 * @notice Unit tests for squad clone deployment and registry.
 */
contract UnitSquadSponsorFactory is UnitSquadSponsorBase {
  address internal _creator = makeAddr('creator');
  address internal _rosterOwner = makeAddr('rosterOwner');
  // forge-lint: disable-next-line(unsafe-typecast)
  bytes32 internal constant _MISSING_SQUAD_ID = bytes32('missing');

  function test_Unit_Factory_CreateSquadExtDeploysClone() external {
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_squadId, _creator);

    assertTrue(_sponsor.code.length > 0);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.sponsor, _sponsor);
    assertEq(uint256(_record.variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
    assertEq(_factory.squadIdBySponsor(_sponsor), _squadId);
  }

  function test_Unit_Factory_CreateSquadHatDeploysClone() external {
    uint256[] memory _customHats = new uint256[](0);
    address _sponsor = _factory.createSquadSponsor(_squadId, 0x100, address(0), _customHats);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.sponsor, _sponsor);
    assertEq(uint256(_record.variant), uint256(ISquadSponsorCommon.SquadVariant.SPONSOR));
    assertEq(_record.topHatId, 0x100);
  }

  function test_Unit_Factory_ConfiguredAddressOwner() external {
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_squadId, _rosterOwner);

    assertEq(SquadSponsorExt(payable(_sponsor)).addressOwner(), _rosterOwner);
  }

  function test_Unit_Factory_DeployerNotOwner_CannotSetPermittedAddress() external {
    address _member = makeAddr('member');

    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_squadId, _rosterOwner);
    SquadSponsorExt _ext = SquadSponsorExt(payable(_sponsor));

    vm.prank(_creator);
    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    _ext.setPermittedAddress(_member, true);

    vm.prank(_rosterOwner);
    _ext.setPermittedAddress(_member, true);
    assertTrue(_ext.isEligible(_member));
  }

  function test_Unit_Factory_CreateWithDepositCreditsFunderShares() external {
    vm.deal(_creator, 3 ether);
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt{value: 3 ether}(_squadId, _rosterOwner);

    assertEq(address(_sponsor).balance, 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_creator), 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_rosterOwner), 0);
  }

  function test_Unit_Factory_ZeroAddressOwnerReverts() external {
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    _factory.createSquadSponsorExt(_squadId, address(0));
  }

  function test_Unit_Factory_SquadCreatedEmitsConfiguredOwner() external {
    vm.recordLogs();
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_squadId, _rosterOwner);

    Vm.Log[] memory _logs = vm.getRecordedLogs();
    bool _found;
    for (uint256 _i; _i < _logs.length; ++_i) {
      if (_logs[_i].topics[0] != ISquadSponsorCommon.SquadCreated.selector) continue;
      // indexed: squadId, addressOwner
      assertEq(_logs[_i].topics[1], _squadId);
      assertEq(address(uint160(uint256(_logs[_i].topics[2]))), _rosterOwner);
      (address _emittedSponsor, ISquadSponsorCommon.SquadVariant _variant) =
        abi.decode(_logs[_i].data, (address, ISquadSponsorCommon.SquadVariant));
      assertEq(_emittedSponsor, _sponsor);
      assertEq(uint256(_variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
      _found = true;
    }
    assertTrue(_found);
  }

  function test_Unit_Factory_DuplicateSquadExtReverts() external {
    _createSquadExt(_squadId);

    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_SquadAlreadyExists.selector, _squadId));
    _factory.createSquadSponsorExt(_squadId, address(this));
  }

  function test_Unit_Factory_DuplicateSquadHatReverts() external {
    uint256[] memory _customHats = new uint256[](0);
    _factory.createSquadSponsor(_squadId, 0x100, address(0), _customHats);

    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_SquadAlreadyExists.selector, _squadId));
    _factory.createSquadSponsor(_squadId, 0x101, address(0), _customHats);
  }

  function test_Unit_Factory_RegistryAfterHatsWiring() external {
    vm.deal(_creator, 1 ether);
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt{value: 1 ether}(_squadId, _creator);

    uint256 _topHatId = 0x200;
    uint256[] memory _customHats = new uint256[](0);

    vm.prank(_creator);
    SquadSponsorExt(payable(_sponsor)).postInitialize(_topHatId, address(0), _customHats);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.topHatId, _topHatId);
    assertEq(SquadSponsorExt(payable(_sponsor)).topHatId(), _topHatId);
    assertTrue(SquadSponsorExt(payable(_sponsor)).hatsWired());
  }

  function test_Unit_Factory_RegisterHatsWiringUnknownSquadReverts() external {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_UnknownSquad.selector, _MISSING_SQUAD_ID));
    _factory.registerHatsWiring(_MISSING_SQUAD_ID, 0x100);
  }

  function test_Unit_Factory_RegisterHatsWiringNotSponsorReverts() external {
    vm.prank(_creator);
    _factory.createSquadSponsorExt(_squadId, _creator);

    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    _factory.registerHatsWiring(_squadId, 0x100);
  }

  function test_Unit_Factory_ConstructorZeroEntryPointReverts() external {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_ZeroField.selector, 'entryPoint'));
    new SquadSponsorFactory(IEntryPoint(address(0)), address(0));
  }

  function test_Unit_Factory_DeploysPaymasterInConstructor() external view {
    assertEq(_factory.PAYMASTER(), address(_paymaster));
  }

  function test_Unit_Factory_HatsReturnsConstant() external view {
    assertEq(_factory.hats(), 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
  }

  /*///////////////////////////////////////////////////////////////
                        createWarGameSponsorExt
  //////////////////////////////////////////////////////////////*/

  function test_Unit_Factory_WarGameSquadIdIsStable() external view {
    bytes32 _expected = keccak256(abi.encode(_squadId, _factory.WAR_GAME_NS(), uint256(1)));
    assertEq(_factory.warGameSquadId(_squadId, 1), _expected);
    assertTrue(_factory.warGameSquadId(_squadId, 1) != _squadId);
  }

  function test_Unit_Factory_CreateWarGameDeploysCloneAndDoesNotRegisterParent() external {
    vm.prank(_creator);
    (address _sponsor, uint256 _round, bytes32 _gameSquadId) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);

    assertEq(_round, 1);
    assertEq(_gameSquadId, _factory.warGameSquadId(_squadId, 1));
    assertEq(_sponsor, _factory.predictWarGameSponsor(_squadId, 1));
    assertTrue(_sponsor.code.length > 0);
    assertEq(SquadSponsorExt(payable(_sponsor)).addressOwner(), _rosterOwner);
    assertEq(SquadSponsorExt(payable(_sponsor)).squadId(), _gameSquadId);

    ISquadSponsorFactory.SquadRecord memory _gameRecord = _factory.squads(_gameSquadId);
    assertEq(_gameRecord.sponsor, _sponsor);
    assertEq(uint256(_gameRecord.variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
    assertEq(_gameRecord.topHatId, 0);
    assertEq(_factory.squadIdBySponsor(_sponsor), _gameSquadId);
    assertEq(_factory.warGameRoundCount(_squadId), 1);

    ISquadSponsorFactory.SquadRecord memory _parentRecord = _factory.squads(_squadId);
    assertEq(_parentRecord.sponsor, address(0));
  }

  function test_Unit_Factory_CreateWarGameTwoRoundsAreIsolated() external {
    vm.startPrank(_creator);
    (address _first, uint256 _round1, bytes32 _id1) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);
    (address _second, uint256 _round2, bytes32 _id2) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);
    vm.stopPrank();

    assertEq(_round1, 1);
    assertEq(_round2, 2);
    assertTrue(_first != _second);
    assertTrue(_id1 != _id2);
    assertEq(_factory.squads(_id1).sponsor, _first);
    assertEq(_factory.squads(_id2).sponsor, _second);
    assertEq(_factory.predictWarGameSponsor(_squadId, 2), _second);
    assertEq(_factory.warGameRoundCount(_squadId), 2);
  }

  function test_Unit_Factory_CreateWarGameThenParentExtStillWorks() external {
    vm.prank(_creator);
    (address _game,, bytes32 _gameSquadId) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);

    vm.prank(_creator);
    address _parent = _factory.createSquadSponsorExt(_squadId, _creator);

    assertTrue(_game != _parent);
    assertEq(_factory.squads(_squadId).sponsor, _parent);
    assertEq(_factory.squads(_gameSquadId).sponsor, _game);
  }

  function test_Unit_Factory_CreateWarGameParentHatsWireDoesNotAffectRound() external {
    vm.prank(_creator);
    address _parent = _factory.createSquadSponsorExt(_squadId, _creator);
    vm.prank(_creator);
    (address _game,, bytes32 _gameSquadId) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);

    uint256[] memory _customHats = new uint256[](0);
    vm.prank(_creator);
    SquadSponsorExt(payable(_parent)).postInitialize(0x200, address(0), _customHats);

    assertEq(_factory.squads(_squadId).topHatId, 0x200);
    assertEq(_factory.squads(_gameSquadId).topHatId, 0);
    assertFalse(SquadSponsorExt(payable(_game)).hatsWired());
  }

  function test_Unit_Factory_CreateWarGameRoundWireDoesNotAffectOtherRound() external {
    vm.startPrank(_rosterOwner);
    (address _first,, bytes32 _id1) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);
    (address _second,, bytes32 _id2) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);

    uint256[] memory _customHats = new uint256[](0);
    SquadSponsorExt(payable(_first)).postInitialize(0x301, address(0), _customHats);
    vm.stopPrank();

    assertTrue(SquadSponsorExt(payable(_first)).hatsWired());
    assertFalse(SquadSponsorExt(payable(_second)).hatsWired());
    assertEq(_factory.squads(_id1).topHatId, 0x301);
    assertEq(_factory.squads(_id2).topHatId, 0);
    assertEq(_factory.squads(_squadId).topHatId, 0);
  }

  function test_Unit_Factory_CreateWarGameWithDepositCreditsFunderShares() external {
    vm.deal(_creator, 3 ether);
    vm.prank(_creator);
    (address _sponsor,,) = _factory.createWarGameSponsorExt{value: 3 ether}(_squadId, _rosterOwner);

    assertEq(address(_sponsor).balance, 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_creator), 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_rosterOwner), 0);
  }

  function test_Unit_Factory_CreateWarGameZeroParentReverts() external {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_ZeroField.selector, 'parentSquadId'));
    _factory.createWarGameSponsorExt(bytes32(0), _rosterOwner);
  }

  function test_Unit_Factory_CreateWarGameZeroAddressOwnerReverts() external {
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    _factory.createWarGameSponsorExt(_squadId, address(0));
  }

  function test_Unit_Factory_CreateWarGameEmitsEvents() external {
    bytes32 _gameSquadId = _factory.warGameSquadId(_squadId, 1);
    address _predicted = _factory.predictWarGameSponsor(_squadId, 1);

    vm.recordLogs();
    vm.prank(_creator);
    (address _sponsor, uint256 _round,) = _factory.createWarGameSponsorExt(_squadId, _rosterOwner);

    assertEq(_round, 1);
    assertEq(_sponsor, _predicted);

    Vm.Log[] memory _logs = vm.getRecordedLogs();
    bool _foundCreated;
    bool _foundWarGame;
    for (uint256 _i; _i < _logs.length; ++_i) {
      if (_logs[_i].topics[0] == ISquadSponsorCommon.SquadCreated.selector) {
        assertEq(_logs[_i].topics[1], _gameSquadId);
        assertEq(address(uint160(uint256(_logs[_i].topics[2]))), _rosterOwner);
        (address _emittedSponsor, ISquadSponsorCommon.SquadVariant _variant) =
          abi.decode(_logs[_i].data, (address, ISquadSponsorCommon.SquadVariant));
        assertEq(_emittedSponsor, _sponsor);
        assertEq(uint256(_variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
        _foundCreated = true;
      }
      if (_logs[_i].topics[0] == ISquadSponsorCommon.WarGameSponsorCreated.selector) {
        assertEq(_logs[_i].topics[1], _squadId);
        assertEq(_logs[_i].topics[2], _gameSquadId);
        assertEq(address(uint160(uint256(_logs[_i].topics[3]))), _sponsor);
        uint256 _emittedRound = abi.decode(_logs[_i].data, (uint256));
        assertEq(_emittedRound, 1);
        _foundWarGame = true;
      }
    }
    assertTrue(_foundCreated);
    assertTrue(_foundWarGame);
  }
}
