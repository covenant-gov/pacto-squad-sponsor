// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

/**
 * @title IPactoSimple7702Account
 * @author Pacto
 * @notice Minimal EIP-7702 account surface for EntryPoint v0.7 UserOps.
 * @dev Remapping shim: pacto-aa sources import bare `interfaces/...`, which resolves here.
 *      Keep in sync with pacto-aa `src/interfaces/IPactoSimple7702Account.sol`. Canonical
 *      account implementation lives in pacto-aa — do not reintroduce the contract in this repo.
 */
interface IPactoSimple7702Account {
  /**
   * @notice Execute a single call. Only EntryPoint or this account (7702 self-call).
   * @param dest Call target.
   * @param value ETH to forward.
   * @param func Calldata for `dest`.
   */
  function execute(address dest, uint256 value, bytes calldata func) external;

  /**
   * @notice Canonical ERC-4337 EntryPoint used by this account.
   * @return entryPoint Address of EntryPoint v0.7.
   */
  function entryPoint() external view returns (IEntryPoint entryPoint);
}
