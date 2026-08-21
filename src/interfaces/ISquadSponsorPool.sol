// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

/**
 * @title ISquadSponsorPool
 * @author Pacto
 * @notice Per-parent ETH vault, pro-rata shares, paymaster-only gas spend, and defacto/wargame slots.
 */
interface ISquadSponsorPool is ISquadSponsorCommon {
  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice One-shot initializer for an EIP-1167 pool clone.
   * @param parentSquadId Production squad identifier this vault is bound to.
   * @param paymaster Chain paymaster authorized to call `spendGas`.
   * @param factory SquadSponsorFactory address.
   */
  function initialize(bytes32 parentSquadId, address paymaster, address factory) external;

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Deposit ETH and mint pro-rata sponsor shares to `msg.sender`.
   */
  function deposit() external payable;

  /**
   * @notice Deposit ETH on behalf of `sponsor` and mint pro-rata shares to that account.
   * @param sponsor Account receiving sponsor shares.
   */
  function depositFor(address sponsor) external payable;

  /**
   * @notice Burn the caller's shares and withdraw a pro-rata ETH share of the pool.
   */
  function withdraw() external;

  /**
   * @notice Transfer ETH to the paymaster after a sponsored UserOp.
   * @param amount Wei to deduct from this squad pool.
   */
  function spendGas(uint256 amount) external;

  /**
   * @notice Set the production sponsor permitted to spend this pool.
   * @dev `onlySlotAdmin` is a no-op until access control is designed.
   * @param sponsor Factory-registered clone whose `pool()` is this contract.
   */
  function setDefacto(address sponsor) external;

  /**
   * @notice Set the current war-game sponsor permitted to spend this pool.
   * @dev `onlySlotAdmin` is a no-op until access control is designed. Overwrites the previous round.
   * @param sponsor Factory-registered clone whose `pool()` is this contract.
   */
  function setWargame(address sponsor) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Production squad identifier this vault is bound to.
   * @return parentSquadId Parent squad id.
   */
  function parentSquadId() external view returns (bytes32 parentSquadId);

  /**
   * @notice Wired paymaster for gas spend.
   * @return paymaster Paymaster address.
   */
  function paymaster() external view returns (address paymaster);

  /**
   * @notice Factory that created this clone.
   * @return factory Factory address.
   */
  function factory() external view returns (address factory);

  /**
   * @notice Production sponsor currently permitted to spend this pool.
   * @return sponsor Defacto slot occupant (`address(0)` if unset).
   */
  function defacto() external view returns (address sponsor);

  /**
   * @notice Current war-game sponsor permitted to spend this pool.
   * @return sponsor Wargame slot occupant (`address(0)` if unset).
   */
  function wargame() external view returns (address sponsor);

  /**
   * @notice Total sponsor shares outstanding for this pool.
   * @return totalShares Aggregate shares.
   */
  function totalShares() external view returns (uint256 totalShares);

  /**
   * @notice Sponsor shares held by an account.
   * @param sponsor Account queried.
   * @return shares Shares owned by `sponsor`.
   */
  function sponsorShares(address sponsor) external view returns (uint256 shares);

  /**
   * @notice Storage-backed ETH available for sponsorship (no `BALANCE` opcode).
   * @return amount Spendable pool wei tracked on deposit / withdraw / spendGas.
   */
  function spendablePoolWei() external view returns (uint256 amount);

  /**
   * @notice Withdrawable ETH for a sponsor at the current pool balance.
   * @param sponsor Account queried.
   * @return amount Pro-rata withdrawable wei.
   */
  function withdrawable(address sponsor) external view returns (uint256 amount);
}
