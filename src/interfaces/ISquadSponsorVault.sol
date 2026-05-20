// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISquadSponsorVault
 * @author Pacto
 * @notice Per-squad ETH pool with pro-rata sponsor shares and paymaster-only gas spend.
 */
interface ISquadSponsorVault {
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
   * @param amount ETH transferred from the vault in wei.
   */
  event GasSpent(address indexed paymaster, uint256 amount);
  /**
   * @notice Emitted when the Ext clone links a Hats top hat.
   * @param topHatId Top hat id bound to this vault.
   */
  event TopHatLinked(uint256 topHatId);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Caller is not the wired paymaster.
  error SquadSponsorVault_NotPaymaster();
  /// @notice Caller is not this squad's Ext clone.
  error SquadSponsorVault_NotExt();
  /// @notice Zero address passed where forbidden.
  error SquadSponsorVault_ZeroAddress();
  /// @notice ETH transfer failed.
  error SquadSponsorVault_TransferFailed();
  /// @notice Deposit amount is zero.
  error SquadSponsorVault_ZeroAmount();
  /// @notice Withdrawer has no shares.
  error SquadSponsorVault_NoShares();
  /// @notice Spend amount exceeds pool balance.
  error SquadSponsorVault_InsufficientBalance();
  /// @notice Top hat already linked for this vault.
  error SquadSponsorVault_TopHatAlreadyLinked();

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice One-shot initializer for an EIP-1167 vault clone.
   * @param squadId Squad identifier bound to this clone.
   * @param ext This squad's Ext clone address.
   * @param paymaster Chain paymaster authorized to call `spendGas`.
   * @param factory SquadSponsorFactory address.
   */
  function initialize(bytes32 squadId, address ext, address paymaster, address factory) external;

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
   * @notice Record the squad's Hats top hat when hat sponsorship is wired.
   * @param topHatId Top hat id for this squad's tree.
   */
  function linkTopHat(uint256 topHatId) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Squad identifier for this clone.
   * @return squadId Bound squad id.
   */
  function squadId() external view returns (bytes32 squadId);

  /**
   * @notice Paired Ext clone for this vault.
   * @return ext Ext clone address.
   */
  function ext() external view returns (address ext);

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
   * @notice Linked Hats top hat id (zero until wired).
   * @return topHatId Top hat id.
   */
  function topHatId() external view returns (uint256 topHatId);

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
