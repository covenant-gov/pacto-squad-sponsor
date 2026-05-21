// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISquadSponsorBase
 * @author Pacto
 * @notice Per-squad ETH pool, pro-rata sponsor shares, paymaster-only gas spend, and eligibility hook.
 */
interface ISquadSponsorBase {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a sponsor deposits ETH and receives shares.
   * @param sponsor Account credited with sponsor shares.
   * @param amount ETH deposited in wei.
   * @param sharesMinted Pro-rata shares minted to `sponsor`.
   */
  event Deposited(address indexed sponsor, uint256 amount, uint256 sharesMinted);
  /**
   * @notice Emitted when a sponsor burns shares and withdraws ETH.
   * @param sponsor Account withdrawing from the pool.
   * @param amount ETH withdrawn in wei.
   * @param sharesBurned Sponsor shares burned from `sponsor`.
   */
  event Withdrawn(address indexed sponsor, uint256 amount, uint256 sharesBurned);
  /**
   * @notice Emitted when the paymaster deducts gas from the pool.
   * @param paymaster Paymaster that received the gas reimbursement.
   * @param amount ETH transferred from the sponsor in wei.
   */
  event GasSpent(address indexed paymaster, uint256 amount);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Caller is not the wired paymaster.
  error SquadSponsorBase_NotPaymaster();
  /// @notice Zero address passed where forbidden.
  error SquadSponsorBase_ZeroAddress();
  /// @notice ETH transfer failed.
  error SquadSponsorBase_TransferFailed();
  /// @notice Deposit amount is zero.
  error SquadSponsorBase_ZeroAmount();
  /// @notice Withdrawer has no shares.
  error SquadSponsorBase_NoShares();
  /// @notice Spend amount exceeds pool balance.
  error SquadSponsorBase_InsufficientBalance();

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice One-shot initializer for shared sponsor clone fields.
   * @param squadId Squad identifier bound to this clone.
   * @param paymaster Chain paymaster authorized to call `spendGas`.
   * @param factory SquadSponsorFactory address.
   */
  function initialize(bytes32 squadId, address paymaster, address factory) external;

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
