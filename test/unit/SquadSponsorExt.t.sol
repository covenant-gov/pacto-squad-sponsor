// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {ISquadSponsorExt} from 'interfaces/ISquadSponsorExt.sol';

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitSquadSponsorExt
 * @author Pacto
 * @notice Unit tests for address-based eligibility and hat wiring auth.
 */
contract UnitSquadSponsorExt is UnitSquadSponsorBase {
  SquadSponsorExt internal _ext;

  address internal _owner = makeAddr('owner');
  address internal _member = makeAddr('member');
  address internal _other = makeAddr('other');

  function setUp() public override {
    super.setUp();
    vm.prank(_owner);
    (, address _extAddr) = _factory.createSquad(_squadId);
    _ext = SquadSponsorExt(_extAddr);
  }

  function test_Unit_Ext_SetPermittedAddress() external {
    vm.prank(_owner);
    _ext.setPermittedAddress(_member, true);

    assertTrue(_ext.isEligible(_member));
    assertFalse(_ext.isEligible(_other));

    vm.prank(_owner);
    _ext.setPermittedAddress(_member, false);
    assertFalse(_ext.isEligible(_member));
  }

  function test_Unit_Ext_SetPermittedAddressOnlyOwner() external {
    vm.prank(_other);
    vm.expectRevert(ISquadSponsorExt.SquadSponsorExt_NotAddressOwner.selector);
    _ext.setPermittedAddress(_member, true);
  }

  function test_Unit_Ext_TransferAddressOwner() external {
    vm.prank(_owner);
    _ext.transferAddressOwner(_other);

    assertEq(_ext.addressOwner(), _other);

    vm.prank(_other);
    _ext.setPermittedAddress(_member, true);
    assertTrue(_ext.isEligible(_member));
  }

  function test_Unit_Ext_PostInitializeFromFactory() external {
    uint256 _topHatId = 0x300;
    address _base = makeAddr('base');

    vm.prank(address(_factory));
    _ext.postInitialize(_topHatId, _base);

    assertTrue(_ext.hatsWired());
    assertEq(_ext.squadSponsorBase(), _base);
  }

  function test_Unit_Ext_PostInitializeFromAddressOwner() external {
    uint256 _topHatId = 0x301;
    address _base = makeAddr('base');

    vm.prank(_owner);
    _ext.postInitialize(_topHatId, _base);

    assertTrue(_ext.hatsWired());
  }

  function test_Unit_Ext_PostInitializeFromHatsAdmin() external {
    uint256 _topHatId = 0x302;
    address _base = makeAddr('base');
    address _hatsAdmin = makeAddr('hatsAdmin');

    _mockHatsAdmin(_hatsAdmin, _topHatId, true);

    vm.prank(_hatsAdmin);
    _ext.postInitialize(_topHatId, _base);

    assertTrue(_ext.hatsWired());
  }

  function test_Unit_Ext_PostInitializeRevertsUnauthorized() external {
    vm.prank(_other);
    vm.expectRevert(ISquadSponsorExt.SquadSponsorExt_NotAllowed.selector);
    _ext.postInitialize(0x303, makeAddr('base'));
  }

  function test_Unit_Ext_PostInitializeRevertsTwice() external {
    vm.prank(address(_factory));
    _ext.postInitialize(0x304, makeAddr('base'));

    vm.expectRevert(ISquadSponsorExt.SquadSponsorExt_HatsAlreadyWired.selector);
    vm.prank(address(_factory));
    _ext.postInitialize(0x305, makeAddr('base2'));
  }

  function test_Unit_Ext_SetPermittedAddressZeroMemberReverts() external {
    vm.prank(_owner);
    vm.expectRevert(ISquadSponsorExt.SquadSponsorExt_ZeroAddress.selector);
    _ext.setPermittedAddress(address(0), true);
  }

  function test_Unit_Ext_PostInitializeZeroBaseReverts() external {
    vm.prank(address(_factory));
    vm.expectRevert(ISquadSponsorExt.SquadSponsorExt_ZeroBase.selector);
    _ext.postInitialize(0x306, address(0));
  }

  function test_Unit_Ext_TransferAddressOwnerZeroReverts() external {
    vm.prank(_owner);
    vm.expectRevert(ISquadSponsorExt.SquadSponsorExt_ZeroAddress.selector);
    _ext.transferAddressOwner(address(0));
  }

  function test_Unit_Ext_InitializeZeroVaultReverts() external {
    address _clone = Clones.clone(_factory.extImplementation());

    vm.expectRevert(ISquadSponsorExt.SquadSponsorExt_ZeroAddress.selector);
    SquadSponsorExt(_clone).initialize(_squadId, address(0), address(_factory), _owner);
  }
}
