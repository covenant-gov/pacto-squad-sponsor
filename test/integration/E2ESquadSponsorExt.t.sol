// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

/**
 * @title E2ESquadSponsorExtTest
 * @author Pacto
 * @notice End-to-end scenarios for `SquadSponsorExt`; inherits `IntegrationBase` (mainnet fork required).
 */
contract E2ESquadSponsorExtTest is IntegrationBase {
  address internal _newOwner = makeAddr('e2eNewAddressOwner');

  /*///////////////////////////////////////////////////////////////
                        integration wiring
  //////////////////////////////////////////////////////////////*/

  function test_integration_extSquadRegisteredInFactory() public withDeployedExtSquad {
    ISquadSponsorFactory.SquadRecord memory _record = _factory.squads(_squadId);

    assertEq(_record.sponsor, address(_extSponsor));
    assertEq(uint256(_record.variant), uint256(ISquadSponsorCommon.SquadVariant.EXT));
    assertEq(_record.topHatId, 0);
    assertEq(_factory.squadIdBySponsor(address(_extSponsor)), _squadId);
  }

  function test_integration_extCloneWiredToFactoryPaymaster() public withDeployedExtSquad {
    assertEq(_extSponsor.paymaster(), address(_paymaster));
    assertEq(_extSponsor.factory(), address(_factory));
    assertEq(_extSponsor.squadId(), _squadId);
  }

  /*///////////////////////////////////////////////////////////////
                        setPermittedAddress
  //////////////////////////////////////////////////////////////*/

  function test_e2e_setPermittedAddress_succeedsWhenOwner() public withDeployedExtSquad {
    address _permit = makeAddr('e2ePermitTarget');

    vm.prank(_addressOwner);
    _extSponsor.setPermittedAddress(_permit, true);

    assertTrue(_extSponsor.permittedAddress(_permit));
    assertTrue(_extSponsor.isEligible(_permit));
  }

  function test_e2e_setPermittedAddress_revertsWhenNotOwner() public withDeployedExtSquad {
    address _target = makeAddr('e2ePermitTarget');

    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    vm.prank(_stranger);
    _extSponsor.setPermittedAddress(_target, true);
  }

  function test_e2e_setPermittedAddress_revertsOnZeroMember() public withDeployedExtSquad {
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    vm.prank(_addressOwner);
    _extSponsor.setPermittedAddress(address(0), true);
  }

  function test_e2e_setPermittedAddress_revertsAfterHatsWired() public withDeployedExtSquad {
    vm.store(address(_extSponsor), bytes32(uint256(6)), bytes32(_E2E_TOP_HAT_ID));

    vm.expectRevert(ISquadSponsorCommon.SS_AlreadyWired.selector);
    vm.prank(_addressOwner);
    _extSponsor.setPermittedAddress(makeAddr('e2eLatePermit'), true);
  }

  function test_e2e_setPermittedAddress_revokesEligibility() public withPermittedMember {
    assertTrue(_extSponsor.isEligible(_member));

    vm.prank(_addressOwner);
    _extSponsor.setPermittedAddress(_member, false);

    assertFalse(_extSponsor.isEligible(_member));
  }

  /*///////////////////////////////////////////////////////////////
                        transferAddressOwner
  //////////////////////////////////////////////////////////////*/

  function test_e2e_transferAddressOwner_succeedsWhenOwner() public withDeployedExtSquad {
    vm.prank(_addressOwner);
    _extSponsor.transferAddressOwner(_newOwner);

    assertEq(_extSponsor.addressOwner(), _newOwner);

    address _permit = makeAddr('e2eAfterTransferPermit');
    vm.prank(_newOwner);
    _extSponsor.setPermittedAddress(_permit, true);
    assertTrue(_extSponsor.isEligible(_permit));
  }

  function test_e2e_transferAddressOwner_revertsWhenNotOwner() public withDeployedExtSquad {
    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    vm.prank(_stranger);
    _extSponsor.transferAddressOwner(_newOwner);
  }

  function test_e2e_transferAddressOwner_revertsOnZeroNewOwner() public withDeployedExtSquad {
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    vm.prank(_addressOwner);
    _extSponsor.transferAddressOwner(address(0));
  }

  function test_e2e_transferAddressOwner_revertsAfterHatsWired() public withDeployedExtSquad {
    vm.store(address(_extSponsor), bytes32(uint256(6)), bytes32(_E2E_TOP_HAT_ID));

    vm.expectRevert(ISquadSponsorCommon.SS_AlreadyWired.selector);
    vm.prank(_addressOwner);
    _extSponsor.transferAddressOwner(_newOwner);
  }

  /*///////////////////////////////////////////////////////////////
                        postInitialize
  //////////////////////////////////////////////////////////////*/

  function test_e2e_postInitialize_succeedsFromAddressOwner() public withDeployedExtSquad {
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = _E2E_CUSTOM_HAT_ID;

    vm.prank(_addressOwner);
    _extSponsor.postInitialize(_E2E_TOP_HAT_ID, address(0), _customHats);

    assertTrue(_extSponsor.hatsWired());
    assertEq(_extSponsor.topHatId(), _E2E_TOP_HAT_ID);
    assertEq(_extSponsor.addressOwner(), address(0));
    assertEq(_factory.squads(_squadId).topHatId, _E2E_TOP_HAT_ID);
  }

  function test_e2e_postInitialize_succeedsFromFactory() public withDeployedExtSquad {
    uint256[] memory _customHats = new uint256[](0);

    vm.prank(address(_factory));
    _extSponsor.postInitialize(_E2E_TOP_HAT_ID, address(0), _customHats);

    assertTrue(_extSponsor.hatsWired());
  }

  function test_e2e_postInitialize_succeedsFromHatsAdmin() public withDeployedExtSquad {
    address _hatsAdmin = makeAddr('e2eHatsAdmin');
    _mockHatsAdmin(_hatsAdmin, _E2E_TOP_HAT_ID, true);

    uint256[] memory _customHats = new uint256[](0);

    vm.prank(_hatsAdmin);
    _extSponsor.postInitialize(_E2E_TOP_HAT_ID, address(0), _customHats);

    assertTrue(_extSponsor.hatsWired());
  }

  function test_e2e_postInitialize_revertsWhenUnauthorized() public withDeployedExtSquad {
    uint256[] memory _customHats = new uint256[](0);

    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    vm.prank(_stranger);
    _extSponsor.postInitialize(_E2E_TOP_HAT_ID, address(0), _customHats);
  }

  function test_e2e_postInitialize_revertsWhenAlreadyWired() public withWiredExtSquad {
    uint256[] memory _customHats = new uint256[](0);

    vm.expectRevert(ISquadSponsorCommon.SS_AlreadyWired.selector);
    vm.prank(address(_factory));
    _extSponsor.postInitialize(_E2E_TOP_HAT_ID + 1, address(0), _customHats);
  }

  function test_e2e_postInitialize_switchesEligibilityToHats() public withPermittedMember {
    assertTrue(_extSponsor.isEligible(_member));

    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = _E2E_CUSTOM_HAT_ID;

    vm.prank(_addressOwner);
    _extSponsor.postInitialize(_E2E_TOP_HAT_ID, address(0), _customHats);

    assertFalse(_extSponsor.isEligible(_member));

    _mockHatWearer(_member, _E2E_CUSTOM_HAT_ID, true);
    assertTrue(_extSponsor.isEligible(_member));
  }

  /*///////////////////////////////////////////////////////////////
                        initialize (fresh clone)
  //////////////////////////////////////////////////////////////*/

  function test_e2e_initialize_revertsWhenAlreadyInitialized() public withDeployedExtSquad {
    SquadSponsorExt _fresh = _newExtClone();

    vm.prank(_addressOwner);
    _fresh.initialize(_squadId, address(_paymaster), address(_factory), _addressOwner);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    _fresh.initialize(_squadId, address(_paymaster), address(_factory), _addressOwner);
  }

  function test_e2e_initialize_revertsOnZeroAddressOwner() public {
    SquadSponsorExt _fresh = _newExtClone();

    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    _fresh.initialize(_initSquadId(), address(_paymaster), address(_factory), address(0));
  }

  function _initSquadId() private view returns (bytes32) {
    return keccak256(abi.encodePacked('e2e.ext.init', block.timestamp, address(this)));
  }
}
