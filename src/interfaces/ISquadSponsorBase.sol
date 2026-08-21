// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

/**
 * @title ISquadSponsorBase
 * @author Pacto
 * @notice Per-squad eligibility clone bound to a shared parent pool.
 */
interface ISquadSponsorBase is ISquadSponsorCommon {
  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Returns whether `member` may have squad gas sponsored.
   * @param member Address evaluated for sponsorship eligibility.
   * @return eligible True when the member qualifies under this clone's rules.
   */
  function isEligible(address member) external view returns (bool eligible);

  /**
   * @notice Storage-backed ETH available for sponsorship on the wired pool (no `BALANCE` opcode).
   * @return amount Spendable pool wei forwarded from `pool()`.
   */
  function spendablePoolWei() external view returns (uint256 amount);

  /**
   * @notice Squad identifier for this clone.
   * @return squadId Bound squad id.
   */
  function squadId() external view returns (bytes32 squadId);

  /**
   * @notice Wired paymaster for gas spend (read through the pool).
   * @return paymaster Paymaster address.
   */
  function paymaster() external view returns (address paymaster);

  /**
   * @notice Factory that created this clone.
   * @return factory Factory address.
   */
  function factory() external view returns (address factory);

  /**
   * @notice Parent ETH vault this clone spends from.
   * @return pool Pool clone address.
   */
  function pool() external view returns (address pool);
}
