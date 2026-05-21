// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title SquadSponsorConstants
 * @author Pacto
 * @notice Static chain infrastructure addresses for squad sponsor contracts.
 */
library SquadSponsorConstants {
  /**
   * @notice Hats Protocol v1 singleton used by squad sponsor contracts.
   * @return Hats address on Ethereum, Sepolia, and Arbitrum One.
   */
  address public constant HATS_ADDRESS = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
}
