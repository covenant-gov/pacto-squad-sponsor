// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

/**
 * @title IPactoSponsorPaymaster
 * @author Pacto
 * @notice ERC-4337 paymaster surface and `paymasterAndData` layout helpers.
 */
interface IPactoSponsorPaymaster is ISquadSponsorCommon {
  /**
   * @notice Squad-scoped paymaster payload appended after the ERC-4337 paymaster header.
   * @param squadId Squad identifier (must match factory registry).
   * @param sponsor Sponsor clone for this squad.
   * @param member Account evaluated for sponsorship eligibility (EOA signer or Safe owner).
   */
  struct PaymasterData {
    bytes32 squadId;
    address sponsor;
    address member;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice EIP-7702 allowlist updated by `ALLOWLIST_ADMIN`.
   * @param previous Previous allowed implementation (`address(0)` rejects all stubs).
   * @param implementation New allowed implementation.
   */
  event Allowed7702ImplementationSet(address indexed previous, address indexed implementation);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Update the EIP-7702 implementation allowlist.
   * @dev Only `ALLOWLIST_ADMIN`. `address(0)` rejects every EIP-7702 delegated sender.
   * @param allowed7702 Canonical `PactoSimple7702Account` (or zero).
   */
  function setAllowed7702Implementation(address allowed7702) external;

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice `paymasterAndData` schema version.
   * @return version Current payload schema version.
   */
  function PAYMASTER_DATA_VERSION() external view returns (uint8 version);

  /**
   * @notice Account authorized to call `setAllowed7702Implementation`.
   * @return admin Immutable allowlist admin set at construction.
   */
  function ALLOWLIST_ADMIN() external view returns (address admin);

  /**
   * @notice Allowed EIP-7702 account implementation (set-code target).
   * @dev Storage slot (not immutable). `address(0)` rejects all EIP-7702 delegated senders.
   *      Deploy seeds this to match `PactoProtocolRegistry.allowed7702Implementation()`; validation
   *      does not read that registry. `ALLOWLIST_ADMIN` may rotate or revoke without redeploying pools.
   * @return implementation Canonical `PactoSimple7702Account` (or zero).
   */
  function ALLOWED_7702_IMPLEMENTATION() external view returns (address implementation);
}
