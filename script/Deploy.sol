// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {Constants} from 'script/Constants.sol';
import {SponsorDeployLib} from 'script/SponsorDeployLib.sol';

/// @notice Chain-level deploy: SquadSponsorFactory + PactoSponsorPaymaster via CREATE2.
contract Deploy is Script {
  function run() external {
    Constants.ChainConfig memory config = Constants.getConfig(block.chainid);
    bytes32 saltFactory = vm.envOr('SPONSOR_FACTORY_SALT', bytes32(0));

    vm.startBroadcast();
    address deployer = msg.sender;

    SponsorDeployLib.Addresses memory addrs =
      SponsorDeployLib.predict(deployer, saltFactory, config.entryPoint, config.hats);

    _assertPredicted(deployer, addrs, config);

    SponsorDeployLib.deploy(addrs, config.entryPoint, config.hats);
    vm.stopBroadcast();
  }

  function _assertPredicted(
    address deployer,
    SponsorDeployLib.Addresses memory addrs,
    Constants.ChainConfig memory config
  ) internal view {
    bytes32 paymasterHash = SponsorDeployLib.paymasterInitCodeHash(config.entryPoint, addrs.factory);
    bytes32 factoryHash = SponsorDeployLib.factoryInitCodeHash(addrs.paymaster, config.hats);

    require(
      vm.computeCreate2Address(addrs.saltPaymaster, paymasterHash, deployer) == addrs.paymaster,
      'paymaster address mismatch'
    );
    require(
      vm.computeCreate2Address(addrs.saltFactory, factoryHash, deployer) == addrs.factory, 'factory address mismatch'
    );
  }
}
