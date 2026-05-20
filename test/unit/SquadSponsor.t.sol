// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';

import {INavePirataRegistry} from '@pacto-gov/interfaces/factory/INavePirataRegistry.sol';

import {UnitSquadSponsorBase} from 'test/unit/UnitSquadSponsorBase.sol';

/**
 * @title UnitSquadSponsor
 * @author Pacto
 * @notice Unit tests for hat-based eligibility.
 */
contract UnitSquadSponsor is UnitSquadSponsorBase {
  address internal constant _REGISTRY = address(uint160(uint256(keccak256('pacto.sponsor.REGISTRY'))));

  uint256 internal constant _TOP_HAT_ID = 0xA001;
  uint256 internal constant _CREW_HAT_ID = 0xA002;
  uint256 internal constant _CAPTAIN_HAT_ID = 0xA003;
  uint256 internal constant _CUSTOM_HAT_ID = 0xA004;

  address internal _crew = makeAddr('crew');
  address internal _captain = makeAddr('captain');
  address internal _custom = makeAddr('custom');
  address internal _outsider = makeAddr('outsider');

  SquadSponsor internal _sponsor;

  function setUp() public override {
    super.setUp();
    vm.etch(_REGISTRY, hex'00');

    (address _vault, address _ext) = _createSquad(_squadId);
    _vault;
    _ext;

    uint256[] memory _customHats = new uint256[](0);
    address _base = _factory.cloneAndWireSquadSponsor(_squadId, _TOP_HAT_ID, _REGISTRY, _customHats);
    _sponsor = SquadSponsor(_base);
  }

  function test_Unit_Sponsor_PactoGovCrewAndCaptainEligible() external {
    _mockRegistryDeployment();
    _mockHatWearer(_crew, _CREW_HAT_ID, true);
    _mockHatWearer(_captain, _CAPTAIN_HAT_ID, true);

    assertTrue(_sponsor.isEligible(_crew));
    assertTrue(_sponsor.isEligible(_captain));
    assertFalse(_sponsor.isEligible(_outsider));
  }

  function test_Unit_Sponsor_CustomHatEligible() external {
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = _CUSTOM_HAT_ID;

    (address _vault, address _ext) = _createSquad(keccak256('custom-squad'));
    _vault;
    _ext;

    address _base = _factory.cloneAndWireSquadSponsor(keccak256('custom-squad'), _TOP_HAT_ID, address(0), _customHats);
    SquadSponsor _customSponsor = SquadSponsor(_base);

    _mockHatWearer(_custom, _CUSTOM_HAT_ID, true);
    assertTrue(_customSponsor.isEligible(_custom));
    assertFalse(_customSponsor.isEligible(_outsider));
  }

  function test_Unit_Sponsor_OnlyCaptainEligible() external {
    _mockRegistryDeployment();
    _mockHatWearer(_crew, _CREW_HAT_ID, false);
    _mockHatWearer(_captain, _CAPTAIN_HAT_ID, true);

    assertFalse(_sponsor.isEligible(_crew));
    assertTrue(_sponsor.isEligible(_captain));
  }

  function test_Unit_Sponsor_RegistryZeroDeploymentUsesCustomHats() external {
    vm.mockCall(
      _REGISTRY,
      abi.encodeWithSelector(INavePirataRegistry.deployment.selector, _TOP_HAT_ID),
      abi.encode(
        INavePirataRegistry.Deployment({
          safe: address(0),
          quartermaster: address(0),
          mutinyModule: address(0),
          treasuryAuthority: address(0),
          squadAdminProxy: address(0),
          topHatId: 0,
          captainHatId: _CAPTAIN_HAT_ID,
          crewHatId: _CREW_HAT_ID,
          squadAdminHatId: 0,
          mutinyRoleHatId: 0,
          quartermasterRoleHatId: 0,
          treasuryAuthorityRoleHatId: 0,
          deployedAt: 0,
          deployer: address(0)
        })
      )
    );

    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = _CUSTOM_HAT_ID;

    (address _vault, address _ext) = _createSquad(keccak256('registry-fallback'));
    _vault;
    _ext;

    address _base =
      _factory.cloneAndWireSquadSponsor(keccak256('registry-fallback'), _TOP_HAT_ID, _REGISTRY, _customHats);
    SquadSponsor _fallbackSponsor = SquadSponsor(_base);

    _mockHatWearer(_custom, _CUSTOM_HAT_ID, true);
    assertTrue(_fallbackSponsor.isEligible(_custom));
    assertFalse(_fallbackSponsor.isEligible(_outsider));
  }

  function test_Unit_Sponsor_CustomEligibleHatsViews() external {
    assertEq(_sponsor.customEligibleHatsLength(), 0);

    uint256[] memory _customHats = new uint256[](2);
    _customHats[0] = 0xC001;
    _customHats[1] = 0xC002;

    (address _vault, address _ext) = _createSquad(keccak256('views-squad'));
    _vault;
    _ext;

    address _base = _factory.cloneAndWireSquadSponsor(keccak256('views-squad'), _TOP_HAT_ID, address(0), _customHats);
    SquadSponsor _viewSponsor = SquadSponsor(_base);

    assertEq(_viewSponsor.customEligibleHatsLength(), 2);
    assertEq(_viewSponsor.customEligibleHats(0), 0xC001);
    assertEq(_viewSponsor.customEligibleHats(1), 0xC002);
    assertEq(_viewSponsor.squadId(), keccak256('views-squad'));
    assertEq(_viewSponsor.topHatId(), _TOP_HAT_ID);
    assertEq(_viewSponsor.registry(), address(0));
  }

  function _mockRegistryDeployment() internal {
    INavePirataRegistry.Deployment memory _deployment = INavePirataRegistry.Deployment({
      safe: address(0),
      quartermaster: address(0),
      mutinyModule: address(0),
      treasuryAuthority: address(0),
      squadAdminProxy: address(0),
      topHatId: _TOP_HAT_ID,
      captainHatId: _CAPTAIN_HAT_ID,
      crewHatId: _CREW_HAT_ID,
      squadAdminHatId: 0,
      mutinyRoleHatId: 0,
      quartermasterRoleHatId: 0,
      treasuryAuthorityRoleHatId: 0,
      deployedAt: 0,
      deployer: address(0)
    });

    vm.mockCall(
      _REGISTRY, abi.encodeWithSelector(INavePirataRegistry.deployment.selector, _TOP_HAT_ID), abi.encode(_deployment)
    );
  }
}
