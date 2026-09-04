// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IPactoProtocolRegistry
 * @author Pacto
 * @notice Minimal surface of the username-system protocol registry used by the squad paymaster.
 * @dev Matches `allowed7702Implementation()` on the live `PactoProtocolRegistry` in pacto-username-nft.
 *      This repo does not depend on the full username package; only this getter is required.
 */
interface IPactoProtocolRegistry {
  /**
   * @notice Live EIP-7702 account implementation allowlist (`address(0)` rejects all 7702 senders).
   * @return allowed7702 Canonical `PactoSimple7702Account` (or zero).
   */
  function allowed7702Implementation() external view returns (address allowed7702);
}
