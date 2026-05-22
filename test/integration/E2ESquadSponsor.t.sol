// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';

/**
 * @title E2ESquadSponsorTest
 * @author Pacto
 * @notice End-to-end scenarios for hat-first `SquadSponsor` clones; inherits `IntegrationBase` (mainnet fork required).
 */
contract E2ESquadSponsorTest is IntegrationBase {
  address internal _wearer = makeAddr('e2eHatWearer');

  /*///////////////////////////////////////////////////////////////
                        integration wiring
  //////////////////////////////////////////////////////////////*/

  function test_integration_hatSponsorRegisteredInFactory() public withDeployedHatSponsor {
    assertEq(_factory.squads(_hatSquadId).sponsor, address(_hatSponsor));
    assertEq(uint256(_factory.squads(_hatSquadId).variant), uint256(ISquadSponsorCommon.SquadVariant.SPONSOR));
    assertEq(_hatSponsor.topHatId(), _E2E_TOP_HAT_ID);
  }

  /*///////////////////////////////////////////////////////////////
                        isEligible
  //////////////////////////////////////////////////////////////*/

  function test_e2e_isEligible_trueWhenCustomHatWearer() public withDeployedHatSponsor {
    _mockHatWearer(_wearer, _E2E_CUSTOM_HAT_ID, true);
    assertTrue(_hatSponsor.isEligible(_wearer));
  }

  function test_e2e_isEligible_falseWhenNotHatWearer() public withDeployedHatSponsor {
    _mockHatWearer(_wearer, _E2E_CUSTOM_HAT_ID, false);
    assertFalse(_hatSponsor.isEligible(_wearer));
  }

  function test_e2e_isEligible_falseWhenTopHatIdZero() public {
    bytes32 _id = _freshSquadId();
    uint256[] memory _customHats = new uint256[](0);
    address _sponsor = _factory.createSquadSponsor(_id, 0, address(0), _customHats);

    assertFalse(SquadSponsor(payable(_sponsor)).isEligible(_wearer));
  }

  /*///////////////////////////////////////////////////////////////
                        views
  //////////////////////////////////////////////////////////////*/

  function test_e2e_customEligibleHatsViews() public withDeployedHatSponsor {
    assertEq(_hatSponsor.customEligibleHatsLength(), 1);
    assertEq(_hatSponsor.customEligibleHats(0), _E2E_CUSTOM_HAT_ID);
    assertEq(_hatSponsor.registry(), address(0));
  }

  function test_e2e_hatSponsorWiredToPaymasterAndFactory() public withDeployedHatSponsor {
    assertEq(_hatSponsor.paymaster(), address(_paymaster));
    assertEq(_hatSponsor.factory(), address(_factory));
  }
}
