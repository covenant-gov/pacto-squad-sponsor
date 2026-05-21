// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitSquadSponsorFactory
 * @author Pacto
 * @notice Unit tests for squad clone deployment and registry.
 */
contract UnitSquadSponsorFactory is UnitSquadSponsorBase {
  address internal _creator = makeAddr('creator');
  // forge-lint: disable-next-line(unsafe-typecast)
  bytes32 internal constant _MISSING_SQUAD_ID = bytes32('missing');

  function test_Unit_Factory_CreateSquadExtDeploysClone() external {
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_squadId);

    assertTrue(_sponsor.code.length > 0);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.sponsor, _sponsor);
    assertEq(uint256(_record.variant), uint256(ISquadSponsorFactory.SquadVariant.EXT));
    assertEq(_factory.squadIdBySponsor(_sponsor), _squadId);
  }

  function test_Unit_Factory_CreateSquadHatDeploysClone() external {
    uint256[] memory _customHats = new uint256[](0);
    address _sponsor = _factory.createSquadSponsor(_squadId, 0x100, address(0), _customHats);

    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);
    assertEq(_record.sponsor, _sponsor);
    assertEq(uint256(_record.variant), uint256(ISquadSponsorFactory.SquadVariant.SPONSOR));
    assertEq(_record.topHatId, 0x100);
  }

  function test_Unit_Factory_FirstDepositorBecomesAddressOwner() external {
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt(_squadId);

    assertEq(SquadSponsorExt(payable(_sponsor)).addressOwner(), _creator);
  }

  function test_Unit_Factory_CreateWithDepositFundsSponsor() external {
    vm.deal(_creator, 3 ether);
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt{value: 3 ether}(_squadId);

    assertEq(address(_sponsor).balance, 3 ether);
    assertEq(ISquadSponsorBase(_sponsor).sponsorShares(_creator), 3 ether);
  }

  function test_Unit_Factory_DuplicateSquadExtReverts() external {
    _createSquadExt(_squadId);

    vm.expectRevert(
      abi.encodeWithSelector(ISquadSponsorFactory.SquadSponsorFactory_SquadAlreadyExists.selector, _squadId)
    );
    _factory.createSquadSponsorExt(_squadId);
  }

  function test_Unit_Factory_DuplicateSquadHatReverts() external {
    uint256[] memory _customHats = new uint256[](0);
    _factory.createSquadSponsor(_squadId, 0x100, address(0), _customHats);

    vm.expectRevert(
      abi.encodeWithSelector(ISquadSponsorFactory.SquadSponsorFactory_SquadAlreadyExists.selector, _squadId)
    );
    _factory.createSquadSponsor(_squadId, 0x101, address(0), _customHats);
  }

  function test_Unit_Factory_RegistryAfterHatsWiring() external {
    vm.deal(_creator, 1 ether);
    vm.prank(_creator);
    address _sponsor = _factory.createSquadSponsorExt{value: 1 ether}(_squadId);

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
    vm.expectRevert(
      abi.encodeWithSelector(ISquadSponsorFactory.SquadSponsorFactory_UnknownSquad.selector, _MISSING_SQUAD_ID)
    );
    _factory.registerHatsWiring(_MISSING_SQUAD_ID, 0x100);
  }

  function test_Unit_Factory_RegisterHatsWiringNotSponsorReverts() external {
    vm.prank(_creator);
    _factory.createSquadSponsorExt(_squadId);

    vm.expectRevert(ISquadSponsorFactory.SquadSponsorFactory_NotSponsor.selector);
    _factory.registerHatsWiring(_squadId, 0x100);
  }

  function test_Unit_Factory_ConstructorZeroPaymasterReverts() external {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorFactory.SquadSponsorFactory_ZeroAddress.selector, 'paymaster'));
    new SquadSponsorFactory(address(0), _HATS);
  }

  function test_Unit_Factory_ConstructorZeroHatsReverts() external {
    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorFactory.SquadSponsorFactory_ZeroAddress.selector, 'hats'));
    new SquadSponsorFactory(address(_paymaster), address(0));
  }
}
