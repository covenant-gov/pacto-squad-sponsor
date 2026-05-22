// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

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
    address _sponsor = _factory.createSquadSponsorExt(_squadId);
    _ext = SquadSponsorExt(payable(_sponsor));
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
    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
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
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = 0xBEEF;

    vm.prank(address(_factory));
    _ext.postInitialize(_topHatId, address(0), _customHats);

    assertTrue(_ext.hatsWired());
    assertEq(_ext.topHatId(), _topHatId);
    assertEq(_ext.customEligibleHatsLength(), 1);
  }

  function test_Unit_Ext_PostInitializeFromAddressOwner() external {
    uint256 _topHatId = 0x301;
    uint256[] memory _customHats = new uint256[](0);

    vm.prank(_owner);
    _ext.postInitialize(_topHatId, address(0), _customHats);

    assertTrue(_ext.hatsWired());
    assertEq(_ext.addressOwner(), address(0));
  }

  function test_Unit_Ext_PostInitializeFromHatsAdmin() external {
    uint256 _topHatId = 0x302;
    uint256[] memory _customHats = new uint256[](0);
    address _hatsAdmin = makeAddr('hatsAdmin');

    _mockHatsAdmin(_hatsAdmin, _topHatId, true);

    vm.prank(_hatsAdmin);
    _ext.postInitialize(_topHatId, address(0), _customHats);

    assertTrue(_ext.hatsWired());
  }

  function test_Unit_Ext_PostInitializeRevertsUnauthorized() external {
    uint256[] memory _customHats = new uint256[](0);

    vm.prank(_other);
    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    _ext.postInitialize(0x303, address(0), _customHats);
  }

  function test_Unit_Ext_PostInitializeRevertsTwice() external {
    uint256[] memory _customHats = new uint256[](0);

    vm.prank(address(_factory));
    _ext.postInitialize(0x304, address(0), _customHats);

    vm.expectRevert(ISquadSponsorCommon.SS_AlreadyWired.selector);
    vm.prank(address(_factory));
    _ext.postInitialize(0x305, address(0), _customHats);
  }

  function test_Unit_Ext_SetPermittedAddressZeroMemberReverts() external {
    vm.prank(_owner);
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    _ext.setPermittedAddress(address(0), true);
  }

  function test_Unit_Ext_SetPermittedAddressAfterWiringReverts() external {
    uint256[] memory _customHats = new uint256[](0);

    vm.prank(_owner);
    _ext.postInitialize(0x306, address(0), _customHats);

    vm.prank(_owner);
    vm.expectRevert(ISquadSponsorCommon.SS_NotAuthorized.selector);
    _ext.setPermittedAddress(_member, true);
  }

  function test_Unit_Ext_TransferAddressOwnerZeroReverts() external {
    vm.prank(_owner);
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    _ext.transferAddressOwner(address(0));
  }

  function test_Unit_Ext_HatStyleInitializeReverts() external {
    uint256[] memory _customHats = new uint256[](0);

    vm.expectRevert(ISquadSponsorCommon.SS_UseAddressInitializer.selector);
    _ext.initialize(_squadId, address(_paymaster), address(_factory), 0x100, address(0), _customHats);
  }

  function test_Unit_Ext_InitializeZeroPaymasterReverts() external {
    address _clone = Clones.clone(_factory.extImplementation());

    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    SquadSponsorExt(payable(_clone)).initialize(_squadId, address(0), address(_factory), _owner);
  }

  function test_Unit_Ext_InitializeZeroAddressOwnerReverts() external {
    address _clone = Clones.clone(_factory.extImplementation());

    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    SquadSponsorExt(payable(_clone)).initialize(_squadId, address(_paymaster), address(_factory), address(0));
  }

  function test_Unit_Ext_PostInitializeSwitchesToHatEligibility() external {
    vm.prank(_owner);
    _ext.setPermittedAddress(_member, true);

    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = 0xBEEF;

    vm.prank(_owner);
    _ext.postInitialize(0x400, address(0), _customHats);

    assertFalse(_ext.isEligible(_member));
    _mockHatWearer(_member, 0xBEEF, true);
    assertTrue(_ext.isEligible(_member));
  }

  function test_Unit_Ext_HatsWiredFalseBeforeWiring() external view {
    assertFalse(_ext.hatsWired());
  }

  function test_Unit_Ext_SetPermittedAddressAlreadyWiredReverts() external {
    vm.store(address(_ext), bytes32(uint256(5)), bytes32(uint256(0x500)));

    vm.prank(_owner);
    vm.expectRevert(ISquadSponsorCommon.SS_AlreadyWired.selector);
    _ext.setPermittedAddress(_member, true);
  }

  function test_Unit_Ext_TransferAddressOwnerAlreadyWiredReverts() external {
    vm.store(address(_ext), bytes32(uint256(5)), bytes32(uint256(0x501)));

    vm.prank(_owner);
    vm.expectRevert(ISquadSponsorCommon.SS_AlreadyWired.selector);
    _ext.transferAddressOwner(_other);
  }

  function test_Unit_Ext_InitializeZeroFactoryReverts() external {
    address _clone = Clones.clone(_factory.extImplementation());

    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    SquadSponsorExt(payable(_clone)).initialize(_squadId, address(_paymaster), address(0), _owner);
  }

  function test_Unit_Ext_InitializeZeroPaymasterAndFactoryReverts() external {
    address _clone = Clones.clone(_factory.extImplementation());

    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    SquadSponsorExt(payable(_clone)).initialize(_squadId, address(0), address(0), _owner);
  }

  function test_Unit_Ext_NotPermittedBeforeWiring() external view {
    assertFalse(_ext.isEligible(_member));
  }
}
