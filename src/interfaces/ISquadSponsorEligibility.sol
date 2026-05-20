// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISquadSponsorEligibility
 * @author Pacto
 * @notice Shared eligibility surface for address-based (`SquadSponsorExt`) and hat-based (`SquadSponsor`) modules.
 */
interface ISquadSponsorEligibility {
  /**
   * @notice Returns whether `member` may have squad gas sponsored.
   * @param member Address evaluated for sponsorship eligibility.
   * @return eligible True when the member qualifies under this module's rules.
   */
  function isEligible(address member) external view returns (bool eligible);
}
