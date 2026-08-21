// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorBase} from 'contracts/abstracts/SquadSponsorBase.sol';

import {INavePirataRegistry} from '@pacto-gov/interfaces/factory/INavePirataRegistry.sol';
import {ISquadSponsor} from 'interfaces/ISquadSponsor.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

/**
 * @title SquadSponsor
 * @author Pacto
 * @notice Per-squad hat-based gas eligibility via PactoGov registry or a custom hat list.
 * @dev Deploy behind an EIP-1167 minimal proxy; HATS is baked in via `SquadSponsorConstants.HATS_ADDRESS`.
 */
contract SquadSponsor is ISquadSponsor, SquadSponsorBase {
  /// @inheritdoc ISquadSponsor
  uint256 public topHatId;
  /// @inheritdoc ISquadSponsor
  address public registry;

  /// @notice Custom eligible hat ids configured at initialization.
  uint256[] internal _customEligibleHats;

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsor
  function initialize(
    bytes32 _squadId,
    address _factory,
    address _pool,
    uint256 _topHatId,
    address _registry,
    uint256[] calldata _customHats
  ) external virtual initializer {
    _sponsorBaseInit(_squadId, _factory, _pool);
    _sponsorHatInit(_topHatId, _registry, _customHats);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsor
  function customEligibleHats(uint256 index) external view returns (uint256 hatId) {
    hatId = _customEligibleHats[index];
  }

  /// @inheritdoc ISquadSponsor
  function customEligibleHatsLength() external view returns (uint256 length) {
    length = _customEligibleHats.length;
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Seeds hat eligibility fields for this clone.
   * @param _topHatId Linked Hats tree top hat id.
   * @param _registry PactoGov registry (`address(0)` for custom-hat-only squads).
   * @param _customHats Optional extra eligible hat ids.
   */
  function _sponsorHatInit(uint256 _topHatId, address _registry, uint256[] calldata _customHats) internal {
    topHatId = _topHatId;
    registry = _registry;

    delete _customEligibleHats;
    uint256 _len = _customHats.length;
    for (uint256 i = 0; i < _len; ++i) {
      _customEligibleHats.push(_customHats[i]);
    }
  }

  /**
   * @notice Wires hat eligibility and records wiring in the factory registry.
   * @param _topHatId Linked Hats tree top hat id.
   * @param _registry PactoGov registry (`address(0)` for custom-hat-only squads).
   * @param _customHats Optional extra eligible hat ids.
   */
  function _wireHats(uint256 _topHatId, address _registry, uint256[] calldata _customHats) internal {
    if (topHatId != 0) revert SS_AlreadyWired();
    _sponsorHatInit(_topHatId, _registry, _customHats);
    ISquadSponsorFactory(factory).registerHatsWiring(squadId, _topHatId);
    emit HatsWired(squadId, _topHatId);
  }

  /// @inheritdoc SquadSponsorBase
  function _isEligible(address member) internal view virtual override returns (bool eligible) {
    if (topHatId == 0) return false;

    if (registry != address(0)) {
      INavePirataRegistry.Deployment memory _deployment = INavePirataRegistry(registry).deployment(topHatId);
      if (_deployment.topHatId != 0) {
        if (_HATS.isWearerOfHat(member, _deployment.crewHatId)) return true;
        if (_HATS.isWearerOfHat(member, _deployment.captainHatId)) return true;
      }
    }

    uint256 _len = _customEligibleHats.length;
    for (uint256 i = 0; i < _len; ++i) {
      if (_HATS.isWearerOfHat(member, _customEligibleHats[i])) return true;
    }
  }
}
