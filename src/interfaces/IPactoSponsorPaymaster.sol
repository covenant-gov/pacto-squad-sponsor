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
   * @param sponsor Sponsor clone for this squad.
   * @param member Account evaluated for sponsorship eligibility (EOA signer or Safe owner).
   */
  struct PaymasterData {
    bytes32 squadId;
    address sponsor;
    address member;
  }

  /**
   * @notice `paymasterAndData` schema version.
   * @return version Current payload schema version.
   */
  function PAYMASTER_DATA_VERSION() external view returns (uint8 version);
}
