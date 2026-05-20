// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IPactoSponsorPaymaster
 * @author Pacto
 * @notice ERC-4337 paymaster surface and `paymasterAndData` layout helpers.
 */
interface IPactoSponsorPaymaster {
  /**
   * @notice Squad-scoped paymaster payload appended after the ERC-4337 paymaster header.
   * @param squadId Squad identifier (must match factory registry).
   * @param vault Vault clone for this squad.
   * @param ext Ext clone for this squad.
   * @param base Hat clone when wired (`address(0)` pre-wiring).
   * @param member Account evaluated for sponsorship eligibility (EOA signer or Safe owner).
   */
  struct PaymasterData {
    bytes32 squadId;
    address vault;
    address ext;
    address base;
    address member;
  }

  /**
   * @notice `paymasterAndData` schema version.
   * @return version Current payload schema version.
   */
  function PAYMASTER_DATA_VERSION() external view returns (uint8 version);
}
