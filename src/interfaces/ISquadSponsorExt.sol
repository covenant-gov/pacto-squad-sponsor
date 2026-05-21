// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsor} from 'interfaces/ISquadSponsor.sol';

/**
 * @title ISquadSponsorExt
 * @author Pacto
 * @notice `ISquadSponsor` clone that gates eligibility with an address permit list until optional hat migration.
 */
interface ISquadSponsorExt is ISquadSponsor {
  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice One-shot initializer for an EIP-1167 Ext clone.
   * @param squadId Squad identifier bound to this clone.
   * @param paymaster Chain paymaster authorized to call `spendGas`.
   * @param factory SquadSponsorFactory address.
   * @param addressOwner Early-bird eligibility admin (first depositor).
   */
  function initialize(bytes32 squadId, address paymaster, address factory, address addressOwner) external;

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Wire hat-based eligibility on this Ext clone.
   * @param topHatId Squad Hats tree top hat id.
   * @param registry PactoGov registry (`address(0)` for custom-hat-only squads).
   * @param customEligibleHats Optional extra eligible hat ids (custom tree path).
   */
  function postInitialize(uint256 topHatId, address registry, uint256[] calldata customEligibleHats) external;

  /**
   * @notice Set whether `member` is eligible for sponsorship via address list.
   * @param member Member address to update.
   * @param permitted True to permit, false to revoke.
   */
  function setPermittedAddress(address member, bool permitted) external;

  /**
   * @notice Transfer the address-list admin role.
   * @param newOwner New address owner.
   */
  function transferAddressOwner(address newOwner) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Early-bird admin for address-list updates.
   * @return owner Address owner.
   */
  function addressOwner() external view returns (address owner);

  /**
   * @notice Whether hat sponsorship has been wired via `postInitialize`.
   * @return wired True after hat migration (`topHatId != 0`).
   */
  function hatsWired() external view returns (bool wired);

  /**
   * @notice Whether `member` is on the address permit list.
   * @param member Address queried.
   * @return permitted True when explicitly permitted.
   */
  function permittedAddress(address member) external view returns (bool permitted);
}
