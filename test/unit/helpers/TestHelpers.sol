// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @dev Contract account with bytecode for smart-account paymaster paths.
contract MockSmartAccount {}

/// @dev Rejects incoming ETH transfers.
contract RejectEthReceiver {
  receive() external payable {
    revert();
  }
}
