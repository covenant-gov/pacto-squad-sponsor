// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Constants} from 'script/Constants.sol';
import {SponsorDeploy} from 'script/SponsorDeploy.sol';

/// @notice Chain-level deploy: SquadSponsorFactory + PactoSponsorPaymaster via CREATE2.
contract Deploy is SponsorDeploy {
  function run() external {
    _config = Constants.getConfig(block.chainid);

    vm.startBroadcast();
    _deployFullSystem(_config.entryPoint, _deploySaltFactory());
    vm.stopBroadcast();

    _logDeployment();
    _writeFullSystemJson(
      _config.entryPoint, _config.navePirataRegistry, address(_factory), address(_paymaster), _broadcastDeployer()
    );
  }
}
