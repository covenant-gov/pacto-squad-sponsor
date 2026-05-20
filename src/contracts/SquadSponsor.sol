// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {INavePirataRegistry} from '@pacto-gov/interfaces/factory/INavePirataRegistry.sol';
import {ISquadSponsor} from 'interfaces/ISquadSponsor.sol';
import {ISquadSponsorEligibility} from 'interfaces/ISquadSponsorEligibility.sol';

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title SquadSponsor
 * @author Pacto
 * @notice Per-squad hat-based gas eligibility via PactoGov registry or a custom hat list.
 * @dev Deploy behind an EIP-1167 minimal proxy; `_HATS` is immutable on the master copy.
 */
contract SquadSponsor is ISquadSponsor, Initializable {
  /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
  //////////////////////////////////////////////////////////////*/

  /// @notice Hats Protocol singleton for wearer checks.
  IHats internal immutable _HATS;

  /*///////////////////////////////////////////////////////////////
                            STORAGE
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsor
  bytes32 public squadId;
  /// @inheritdoc ISquadSponsor
  uint256 public topHatId;
  /// @inheritdoc ISquadSponsor
  address public registry;
  /// @notice Custom eligible hat ids configured at initialization.
  uint256[] internal _customEligibleHats;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Master-copy constructor; bakes the Hats singleton into implementation runtime code.
   * @param hats_ Hats Protocol address for this chain.
   */
  constructor(IHats hats_) {
    _HATS = hats_;
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsor
  function initialize(
    bytes32 _squadId,
    uint256 _topHatId,
    address _registry,
    uint256[] calldata _customHats
  ) external initializer {
    squadId = _squadId;
    topHatId = _topHatId;
    registry = _registry;

    uint256 _len = _customHats.length;
    for (uint256 i = 0; i < _len; ++i) {
      _customEligibleHats.push(_customHats[i]);
    }
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorEligibility
  function isEligible(address member) external view returns (bool eligible) {
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

  /// @inheritdoc ISquadSponsor
  function customEligibleHats(uint256 index) external view returns (uint256 hatId) {
    hatId = _customEligibleHats[index];
  }

  /// @inheritdoc ISquadSponsor
  function customEligibleHatsLength() external view returns (uint256 length) {
    length = _customEligibleHats.length;
  }
}
