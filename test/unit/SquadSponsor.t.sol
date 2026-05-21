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

    uint256[] memory _customHats = new uint256[](0);
    address _sponsorAddr = _factory.createSquadSponsor(_squadId, _TOP_HAT_ID, _REGISTRY, _customHats);
    _sponsor = SquadSponsor(payable(_sponsorAddr));
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

    address _sponsorAddr = _factory.createSquadSponsor(keccak256('custom-squad'), _TOP_HAT_ID, address(0), _customHats);
    SquadSponsor _customSponsor = SquadSponsor(payable(_sponsorAddr));

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

  function test_Unit_Sponsor_OnlyCrewEligible() external {
    _mockRegistryDeployment();
    _mockHatWearer(_crew, _CREW_HAT_ID, true);
    _mockHatWearer(_captain, _CAPTAIN_HAT_ID, false);

    assertTrue(_sponsor.isEligible(_crew));
    assertFalse(_sponsor.isEligible(_captain));
  }

  function test_Unit_Sponsor_SecondCustomHatEligible() external {
    uint256[] memory _customHats = new uint256[](2);
    _customHats[0] = 0xC010;
    _customHats[1] = _CUSTOM_HAT_ID;

    address _sponsorAddr =
      _factory.createSquadSponsor(keccak256('second-custom-hat'), _TOP_HAT_ID, address(0), _customHats);
    SquadSponsor _customSponsor = SquadSponsor(payable(_sponsorAddr));

    _mockHatWearer(_custom, _CUSTOM_HAT_ID, true);
    assertTrue(_customSponsor.isEligible(_custom));
    assertFalse(_customSponsor.isEligible(_outsider));
  }

  function test_Unit_Sponsor_ZeroTopHatIdNotEligible() external {
    uint256[] memory _customHats = new uint256[](0);
    address _sponsorAddr = _factory.createSquadSponsor(keccak256('zero-top-hat'), 0, address(0), _customHats);
    SquadSponsor _zeroTopSponsor = SquadSponsor(payable(_sponsorAddr));

    assertFalse(_zeroTopSponsor.isEligible(_crew));
  }

  function test_Unit_Sponsor_DepositAndWithdrawable() external {
    vm.deal(address(this), 1 ether);
    _sponsor.deposit{value: 1 ether}();

    assertEq(_sponsor.withdrawable(address(this)), 1 ether);
    assertEq(_sponsor.sponsorShares(address(this)), 1 ether);
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

    address _sponsorAddr =
      _factory.createSquadSponsor(keccak256('registry-fallback'), _TOP_HAT_ID, _REGISTRY, _customHats);
    SquadSponsor _fallbackSponsor = SquadSponsor(payable(_sponsorAddr));

    _mockHatWearer(_custom, _CUSTOM_HAT_ID, true);
    assertTrue(_fallbackSponsor.isEligible(_custom));
    assertFalse(_fallbackSponsor.isEligible(_outsider));
  }

  function test_Unit_Sponsor_CustomEligibleHatsViews() external {
    assertEq(_sponsor.customEligibleHatsLength(), 0);

    uint256[] memory _customHats = new uint256[](2);
    _customHats[0] = 0xC001;
    _customHats[1] = 0xC002;

    address _sponsorAddr = _factory.createSquadSponsor(keccak256('views-squad'), _TOP_HAT_ID, address(0), _customHats);
    SquadSponsor _viewSponsor = SquadSponsor(payable(_sponsorAddr));

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
