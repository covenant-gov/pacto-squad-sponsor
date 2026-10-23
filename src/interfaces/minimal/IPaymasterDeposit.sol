// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title IPaymasterDeposit
 * @author Pacto
 * @notice Minimal surface for topping up an ERC-4337 paymaster EntryPoint deposit.
 * @dev Matches `BasePaymaster.deposit()` from account-abstraction v0.7 (not on `IPaymaster`).
 */
interface IPaymasterDeposit {
  /**
   * @notice Forward `msg.value` into `entryPoint.depositTo(address(this))`.
   */
  function deposit() external payable;
}
