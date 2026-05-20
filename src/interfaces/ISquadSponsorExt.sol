// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorEligibility} from 'interfaces/ISquadSponsorEligibility.sol';

/**
 * @title ISquadSponsorExt
 * @author Pacto
 * @notice Per-squad address-based eligibility module deployed before hat wiring.
 */
interface ISquadSponsorExt is ISquadSponsorEligibility {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when an address is added or removed from the permit list.
   * @param member Address whose permit status changed.
   * @param permitted True when added to the list, false when removed.
   */
  event PermittedAddressUpdated(address indexed member, bool permitted);
  /**
   * @notice Emitted when hat sponsorship replaces address-based eligibility.
   * @param squadId Squad identifier for this Ext clone.
   * @param topHatId Linked Hats top hat id.
   * @param squadSponsorBase Hat-based eligibility clone wired for this squad.
   */
  event HatsSponsorshipWired(bytes32 indexed squadId, uint256 topHatId, address squadSponsorBase);
  /**
   * @notice Emitted when address owner role is transferred.
   * @param previousOwner Outgoing address-list admin.
   * @param newOwner Incoming address-list admin.
   */
  event AddressOwnerTransferred(address indexed previousOwner, address indexed newOwner);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Caller is not the address owner.
  error SquadSponsorExt_NotAddressOwner();
  /// @notice Caller is not authorized to wire hat sponsorship.
  error SquadSponsorExt_NotAllowed();
  /// @notice Hat sponsorship already wired for this squad.
  error SquadSponsorExt_HatsAlreadyWired();
  /// @notice New owner address is zero.
  error SquadSponsorExt_ZeroAddress();
  /// @notice Squad sponsor base address is zero.
  error SquadSponsorExt_ZeroBase();

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice One-shot initializer for an EIP-1167 Ext clone.
   * @param squadId Squad identifier bound to this clone.
   * @param vault Paired vault clone address.
   * @param factory SquadSponsorFactory address.
   * @param addressOwner Early-bird eligibility admin (first depositor).
   */
  function initialize(bytes32 squadId, address vault, address factory, address addressOwner) external;

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Set whether `member` is eligible for sponsorship via address list.
   * @param member Member address to update.
   * @param permitted True to permit, false to revoke.
   */
  function setPermittedAddress(address member, bool permitted) external;

  /**
   * @notice Wire hat-based eligibility and link the vault top hat.
   * @param topHatId Squad Hats tree top hat id.
   * @param squadSponsorBase Hat-based eligibility clone for this squad.
   */
  function postInitialize(uint256 topHatId, address squadSponsorBase) external;

  /**
   * @notice Transfer the address-list admin role.
   * @param newOwner New address owner.
   */
  function transferAddressOwner(address newOwner) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Squad identifier for this clone.
   * @return squadId Bound squad id.
   */
  function squadId() external view returns (bytes32 squadId);

  /**
   * @notice Paired vault clone for this Ext module.
   * @return vault Vault clone address.
   */
  function vault() external view returns (address vault);

  /**
   * @notice Factory that created this clone.
   * @return factory Factory address.
   */
  function factory() external view returns (address factory);

  /**
   * @notice Early-bird admin for address-list updates.
   * @return owner Address owner.
   */
  function addressOwner() external view returns (address owner);

  /**
   * @notice Whether hat sponsorship has been wired.
   * @return wired True after `postInitialize`.
   */
  function hatsWired() external view returns (bool wired);

  /**
   * @notice Hat-based eligibility clone once wired.
   * @return base SquadSponsor clone address.
   */
  function squadSponsorBase() external view returns (address base);

  /**
   * @notice Whether `member` is on the address permit list.
   * @param member Address queried.
   * @return permitted True when explicitly permitted.
   */
  function permittedAddress(address member) external view returns (bool permitted);
}
