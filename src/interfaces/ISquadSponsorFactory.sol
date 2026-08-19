// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

/**
 * @title ISquadSponsorFactory
 * @author Pacto
 * @notice Chain singleton that deploys per-squad sponsor clones.
 */
interface ISquadSponsorFactory is ISquadSponsorCommon {
  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice On-chain registry row for a squad's sponsor clone.
   * @param sponsor Sponsor clone address.
   * @param variant Which implementation was deployed.
   * @param topHatId Linked Hats top hat id (zero until wired on Ext clones).
   */
  struct SquadRecord {
    address sponsor;
    SquadVariant variant;
    uint256 topHatId;
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Deploy an Ext clone for `squadId` with `addressOwner` as address-list admin.
   * @dev Optional ETH credits sponsor shares to `msg.sender` (funder), not necessarily `addressOwner`.
   * @param squadId Squad identifier from the app.
   * @param addressOwner Non-zero Ext eligibility admin (may differ from the deployer).
   * @return sponsor New Ext clone address.
   */
  function createSquadSponsorExt(bytes32 squadId, address addressOwner) external payable returns (address sponsor);

  /**
   * @notice Deploy a hat-first SquadSponsor clone for `squadId`.
   * @param squadId Squad identifier from the app.
   * @param topHatId Linked top hat id.
   * @param registry PactoGov registry (`address(0)` for custom hats only).
   * @param customEligibleHats Custom eligible hat ids.
   * @return sponsor New SquadSponsor clone address.
   */
  function createSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external payable returns (address sponsor);

  /**
   * @notice Deploy a war-game Ext clone for the next round of `parentSquadId`.
   * @dev Optional ETH credits sponsor shares to `msg.sender`. Does not register or wire `parentSquadId`.
   * @param parentSquadId Production squad identifier (`keccak256(parentId)`).
   * @param addressOwner Non-zero Ext eligibility admin for this round clone.
   * @return sponsor New Ext clone address.
   * @return round 1-indexed round assigned to this clone.
   * @return gameSquadId Derived registry id (`warGameSquadId(parentSquadId, round)`).
   */
  function createWarGameSponsorExt(
    bytes32 parentSquadId,
    address addressOwner
  ) external payable returns (address sponsor, uint256 round, bytes32 gameSquadId);

  /**
   * @notice Callback from a sponsor clone after successful hat wiring.
   * @param squadId Squad identifier.
   * @param topHatId Linked top hat id.
   */
  function registerHatsWiring(bytes32 squadId, uint256 topHatId) external;

  /**
   * @notice Stake ETH on the paymaster via EntryPoint (FCFS single-staker slot).
   * @dev Initial stake requires `msg.value >= 0.1 ether` and `unstakeDelaySec >= 1 days`.
   *      Current staker may top up with any positive value. Occupied slot blocks other callers.
   * @param unstakeDelaySec Unstake delay (seconds). May only increase on EntryPoint.
   */
  function addPaymasterStake(uint32 unstakeDelaySec) external payable;

  /**
   * @notice Begin unlocking the paymaster EntryPoint stake. Only the current staker.
   */
  function unlockPaymasterStake() external;

  /**
   * @notice Withdraw unlocked paymaster stake to `to` and clear the FCFS slot. Only the current staker.
   * @param to Recipient of stake ETH.
   */
  function withdrawPaymasterStake(address payable to) external;

  /**
   * @notice Withdraw paymaster EntryPoint deposit to `to`. Only the current staker.
   * @param to Recipient of deposit ETH.
   * @param amount Wei to withdraw.
   */
  function withdrawPaymasterDeposit(address payable to, uint256 amount) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Minimum initial paymaster stake (Alchemy Sepolia-compatible floor).
   * @return minimumWei Required wei for the first FCFS stake.
   */
  function MIN_PAYMASTER_STAKE_WEI() external view returns (uint256 minimumWei);

  /**
   * @notice Minimum unstake delay for initial paymaster stake.
   * @return minimumSec Required delay in seconds.
   */
  function MIN_UNSTAKE_DELAY_SEC() external view returns (uint32 minimumSec);

  /**
   * @notice Wired paymaster for all squad sponsor clones.
   * @return paymaster Paymaster address.
   */
  function PAYMASTER() external view returns (address paymaster);

  /**
   * @notice Address holding the FCFS paymaster stake slot (`address(0)` if vacant).
   * @return staker Current staker.
   */
  function paymasterStaker() external view returns (address staker);

  /**
   * @notice Hats Protocol singleton used by sponsor clones.
   * @return hats Hats address.
   */
  function hats() external view returns (address hats);

  /**
   * @notice SquadSponsor implementation used for EIP-1167 clones.
   * @return implementation Master copy address.
   */
  function sponsorImplementation() external view returns (address implementation);

  /**
   * @notice SquadSponsorExt implementation used for EIP-1167 clones.
   * @return implementation Master copy address.
   */
  function extImplementation() external view returns (address implementation);

  /**
   * @notice Registry row for a squad.
   * @param squadId Squad identifier.
   * @return record Sponsor clone, variant, and top hat id.
   */
  function squads(bytes32 squadId) external view returns (SquadRecord memory record);

  /**
   * @notice Resolve squad id from a sponsor clone address.
   * @param sponsor Sponsor clone address.
   * @return squadId Bound squad id.
   */
  function squadIdBySponsor(address sponsor) external view returns (bytes32 squadId);

  /**
   * @notice Namespace mixed into war-game `squadId` derivation.
   * @return namespace `keccak256("pacto.sponsor.wargame")`.
   */
  function WAR_GAME_NS() external view returns (bytes32 namespace);

  /**
   * @notice Number of war-game rounds created for `parentSquadId`.
   * @param parentSquadId Production squad identifier.
   * @return count Highest assigned round (0 if none).
   */
  function warGameRoundCount(bytes32 parentSquadId) external view returns (uint256 count);

  /**
   * @notice Derived registry id for a war-game round clone.
   * @param parentSquadId Production squad identifier.
   * @param round 1-indexed war-game round.
   * @return gameSquadId `keccak256(abi.encode(parentSquadId, WAR_GAME_NS, round))`.
   */
  function warGameSquadId(bytes32 parentSquadId, uint256 round) external view returns (bytes32 gameSquadId);

  /**
   * @notice CREATE2 address for a war-game Ext clone (whether or not it exists).
   * @param parentSquadId Production squad identifier.
   * @param round 1-indexed war-game round.
   * @return sponsor Predicted clone address.
   */
  function predictWarGameSponsor(bytes32 parentSquadId, uint256 round) external view returns (address sponsor);
}
