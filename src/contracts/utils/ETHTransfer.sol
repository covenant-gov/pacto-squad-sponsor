// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

/**
 * @title ETHTransfer
 * @author Pacto
 * @notice Shared ETH send helper for squad sponsor contracts.
 */
library ETHTransfer {
  /**
   * @notice Sends ETH to `to` and reverts on failure.
   * @param to Recipient address.
   * @param amount Wei to send.
   */
  function sendEth(address to, uint256 amount) internal {
    (bool _ok,) = to.call{value: amount}('');
    if (!_ok) revert ISquadSponsorCommon.SS_TransferFailed();
  }
}
