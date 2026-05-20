// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorEligibility} from 'interfaces/ISquadSponsorEligibility.sol';

/**
 * @title ISquadSponsor
 * @author Pacto
 * @notice Per-squad hat-based gas eligibility (PactoGov registry path or custom hat list).
 */
interface ISquadSponsor is ISquadSponsorEligibility {
  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice One-shot initializer for an EIP-1167 hat clone.
   * @param squadId Squad identifier bound to this clone.
   * @param topHatId Linked Hats tree top hat id.
   * @param registry PactoGov registry (`address(0)` for custom-hat-only squads).
   * @param customEligibleHats Optional extra eligible hat ids (custom tree path).
   */
  function initialize(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Squad identifier for this clone.
   * @return squadId Bound squad id.
   */
  function squadId() external view returns (bytes32 squadId);

  /**
   * @notice Linked top hat id for registry lookups.
   * @return topHatId Top hat id.
   */
  function topHatId() external view returns (uint256 topHatId);

  /**
   * @notice Optional pacto-gov registry for PactoGov crew + captain hats.
   * @return registry Registry address.
   */
  function registry() external view returns (address registry);

  /**
   * @notice Custom eligible hat id at index.
   * @param index Index into the configured list.
   * @return hatId Hat id at `index`.
   */
  function customEligibleHats(uint256 index) external view returns (uint256 hatId);

  /**
   * @notice Count of custom eligible hats configured at initialization.
   * @return length Array length.
   */
  function customEligibleHatsLength() external view returns (uint256 length);
}
