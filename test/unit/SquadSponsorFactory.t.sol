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
}
