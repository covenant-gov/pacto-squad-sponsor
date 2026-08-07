// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title ISquadSponsorCommon
 * @author Pacto
 * @notice Shared errors and events for squad sponsor contracts.
 */
interface ISquadSponsorCommon {
  /*///////////////////////////////////////////////////////////////
                            ENUMS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Which sponsor implementation was cloned for a squad.
   * @param NONE Unregistered squad.
   * @param SPONSOR Hat-first `SquadSponsor` clone.
   * @param EXT Address-first `SquadSponsorExt` clone.
   */
  enum SquadVariant {
    NONE,
    SPONSOR,
    EXT
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice A sponsor deposited ETH and received shares.
   * @param sponsor Account credited with sponsor shares.
   * @param amount ETH deposited in wei.
   * @param sharesMinted Pro-rata shares minted to `sponsor`.
   */
  event Deposited(address indexed sponsor, uint256 amount, uint256 sharesMinted);

  /**
   * @notice A sponsor burned shares and withdrew ETH.
   * @param sponsor Account withdrawing from the pool.
   * @param amount ETH withdrawn in wei.
   * @param sharesBurned Sponsor shares burned from `sponsor`.
   */
  event Withdrawn(address indexed sponsor, uint256 amount, uint256 sharesBurned);

  /**
   * @notice The paymaster deducted gas from a sponsor pool.
   * @param paymaster Paymaster that received the gas reimbursement.
   * @param amount ETH transferred from the sponsor in wei.
   */
  event GasSpent(address indexed paymaster, uint256 amount);

  /**
   * @notice Hat eligibility was wired for a squad sponsor clone.
   * @param squadId Squad identifier for this clone.
   * @param topHatId Linked Hats top hat id.
   */
  event HatsWired(bytes32 indexed squadId, uint256 topHatId);

  /**
   * @notice A sponsor clone was created for a squad.
   * @param squadId Squad identifier registered by the factory.
   * @param sponsor New sponsor clone address.
   * @param variant Which implementation was deployed.
   * @param addressOwner Ext path: configured address-list admin. Hats path: deployer (`msg.sender`).
   */
  event SquadCreated(bytes32 indexed squadId, address sponsor, SquadVariant variant, address indexed addressOwner);

  /**
   * @notice An address was added or removed from the Ext permit list.
   * @param member Address whose permit status changed.
   * @param permitted True when added to the list, false when removed.
   */
  event PermittedAddressUpdated(address indexed member, bool permitted);

  /**
   * @notice The Ext address-list admin role was transferred.
   * @param previousOwner Outgoing address-list admin.
   * @param newOwner Incoming address-list admin.
   */
  event OwnerTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @notice ETH was added to the paymaster EntryPoint stake via the factory.
   * @param staker Account holding the FCFS stake slot.
   * @param amount Wei forwarded to `addStake`.
   * @param unstakeDelaySec Unstake delay applied (or increased) for this stake.
   */
  event PaymasterStakeAdded(address indexed staker, uint256 amount, uint32 unstakeDelaySec);

  /**
   * @notice The paymaster EntryPoint stake unlock was started.
   * @param staker Account holding the FCFS stake slot.
   */
  event PaymasterStakeUnlocked(address indexed staker);

  /**
   * @notice The paymaster EntryPoint stake was withdrawn and the FCFS slot cleared.
   * @param staker Account that held the FCFS stake slot.
   * @param to Recipient of withdrawn stake ETH.
   */
  event PaymasterStakeWithdrawn(address indexed staker, address indexed to);

  /**
   * @notice EntryPoint deposit was withdrawn via the factory by the current staker.
   * @param staker Account holding the FCFS stake slot.
   * @param to Recipient of withdrawn deposit ETH.
   * @param amount Wei withdrawn from the paymaster EntryPoint deposit.
   */
  event PaymasterDepositWithdrawn(address indexed staker, address indexed to, uint256 amount);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Caller is not the wired paymaster.
  error SS_NotPaymaster();
  /// @notice Zero address passed where forbidden.
  error SS_ZeroAddress();
  /// @notice ETH transfer failed.
  error SS_TransferFailed();
  /// @notice Deposit amount is zero.
  error SS_ZeroAmount();
  /// @notice Withdrawer has no shares.
  error SS_NoShares();
  /// @notice Spend amount exceeds pool balance.
  error SS_InsufficientBalance();
  /// @notice Caller is not authorized for this action.
  error SS_NotAuthorized();
  /// @notice Hat sponsorship is already wired for this clone.
  error SS_AlreadyWired();
  /// @notice Wrong initializer overload for this clone variant.
  error SS_UseAddressInitializer();

  /**
   * @notice Zero value passed for a named field.
   * @param field Name of the argument that was zero.
   */
  error SS_ZeroField(string field);

  /**
   * @notice Squad id already registered.
   * @param squadId Duplicate squad identifier.
   */
  error SS_SquadAlreadyExists(bytes32 squadId);

  /**
   * @notice Unknown squad id.
   * @param squadId Squad identifier not found in the registry.
   */
  error SS_UnknownSquad(bytes32 squadId);

  /**
   * @notice Unsupported paymaster payload version.
   * @param version Unsupported version byte from `paymasterAndData`.
   */
  error SS_InvalidVersion(uint8 version);

  /**
   * @notice Sponsor address does not match factory registry.
   * @param squadId Squad identifier with mismatched clone address.
   */
  error SS_CloneMismatch(bytes32 squadId);

  /**
   * @notice EOA and EIP-7702 senders must use themselves as the eligibility member.
   * @param sender `userOp.sender` for the UserOperation.
   * @param member Member address supplied in `paymasterAndData`.
   */
  error SS_InvalidMemberBinding(address sender, address member);

  /**
   * @notice EIP-7702 delegated implementation is not the allowlisted account.
   * @param implementation Address extracted from the `0xef0100` delegation stub.
   */
  error SS_Invalid7702Implementation(address implementation);

  /**
   * @notice Paymaster stake slot is already held by another address.
   * @param staker Current FCFS staker.
   */
  error SS_StakeSlotOccupied(address staker);

  /// @notice Caller is not the current FCFS paymaster staker.
  error SS_NotPaymasterStaker();

  /**
   * @notice Initial stake amount is below the required floor.
   * @param amount Wei supplied.
   * @param minimum Required minimum wei.
   */
  error SS_StakeTooSmall(uint256 amount, uint256 minimum);

  /**
   * @notice Unstake delay is below the required floor.
   * @param delaySec Delay supplied.
   * @param minimum Required minimum delay in seconds.
   */
  error SS_UnstakeDelayTooShort(uint32 delaySec, uint32 minimum);
}
