// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {Constants} from 'script/Constants.sol';

/// @notice Chain-level deploy: SquadSponsorFactory + PactoSponsorPaymaster (Phase 3).
contract Deploy is Script {
  function run() external {
    Constants.ChainConfig memory config = Constants.getConfig(block.chainid);
    // Phase 1+: use config.entryPoint, config.hats; persist deploy outputs to Constants + deployments JSON.

    config;

    vm.startBroadcast();
    // Phase 1+: deploy here.
    vm.stopBroadcast();
  }
}
