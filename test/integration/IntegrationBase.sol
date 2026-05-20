// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Constants} from 'script/Constants.sol';
import {Test} from 'forge-std/Test.sol';

/// @dev Integration / e2e tests fork **mainnet** (production Hats, Safe, registry addresses).
/// Sepolia is for deployed-contract + frontend live testing only — not the integration fork target.
contract IntegrationBase is Test {
  function _forkMainnet() internal {
    Constants.ChainConfig memory config = Constants.getConfig(1);
    vm.createSelectFork(vm.rpcUrl('mainnet'), config.mainnetForkBlock);
  }
}
