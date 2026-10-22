// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title PaymasterHeadroomLib
 * @author Pacto
 * @notice Pool-balance headroom required before a paymaster accepts a UserOp.
 */
library PaymasterHeadroomLib {
  /// @notice Headroom versus `maxCost`, in basis points (115%).
  uint256 internal constant _HEADROOM_BPS = 11_500;
  /// @notice Basis-point denominator.
  uint256 internal constant _BPS_DENOMINATOR = 10_000;

  /**
   * @notice Wei the pool must hold before sponsoring `maxCost`.
   * @param maxCost EntryPoint-reported maximum cost of the UserOp.
   * @return required Required pool wei (`maxCost * 11500 / 10000`).
   */
  function requiredWei(uint256 maxCost) internal pure returns (uint256 required) {
    required = (maxCost * _HEADROOM_BPS) / _BPS_DENOMINATOR;
  }
}
