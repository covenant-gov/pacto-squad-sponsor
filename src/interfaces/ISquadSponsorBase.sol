// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

/**
 * @title ISquadSponsorBase
 * @author Pacto
 * @notice Per-squad ETH pool, pro-rata sponsor shares, paymaster-only gas spend, and eligibility hook.
 */
interface ISquadSponsorBase is ISquadSponsorCommon {
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
   * @notice Storage-backed ETH available for sponsorship (no `BALANCE` opcode).
   * @return amount Spendable pool wei tracked on deposit / withdraw / spendGas.
   */
  function spendablePoolWei() external view returns (uint256 amount);

  /**
   * @notice Squad identifier for this clone.
   * @return squadId Bound squad id.
   */
  function squadId() external view returns (bytes32 squadId);

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
   * @notice Withdrawable ETH for a sponsor at the current pool balance.
   * @param sponsor Account queried.
   * @return amount Pro-rata withdrawable wei.
   */
  function withdrawable(address sponsor) external view returns (uint256 amount);
}
