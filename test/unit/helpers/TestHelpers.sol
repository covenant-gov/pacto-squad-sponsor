// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @dev Contract account with bytecode for smart-account paymaster paths.
contract MockSmartAccount {}

/// @dev Minimal sponsor-shaped view for pool slot checks.
contract MockPoolBoundSponsor {
  address private immutable _POOL;

  constructor(address pool_) {
    _POOL = pool_;
  }

  function pool() external view returns (address) {
    return _POOL;
  }
}

/// @dev Rejects incoming ETH transfers.
contract RejectEthReceiver {
  receive() external payable {
    revert();
  }
}
