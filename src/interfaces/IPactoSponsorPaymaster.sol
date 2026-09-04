// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
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
                            VIEWS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice `paymasterAndData` schema version.
   * @return version Current payload schema version.
   */
  function PAYMASTER_DATA_VERSION() external view returns (uint8 version);

  /**
   * @notice Username-system protocol registry that owns the EIP-7702 allowlist slot.
   * @return registry Live `PactoProtocolRegistry` (same instance as the global paymaster).
   */
  function REGISTRY() external view returns (IPactoProtocolRegistry registry);

  /**
   * @notice Allowed EIP-7702 account implementation (set-code target).
   * @dev Registry-backed: reads `REGISTRY.allowed7702Implementation()`. `address(0)` rejects all EIP-7702
   *      delegated senders. Update via registry owner `set(Allowed7702Implementation, …)` — no paymaster redeploy.
   * @return implementation Canonical `PactoSimple7702Account` (or zero).
   */
  function ALLOWED_7702_IMPLEMENTATION() external view returns (address implementation);
}
