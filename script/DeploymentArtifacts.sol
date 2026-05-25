// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {VmSafe} from 'forge-std/Vm.sol';

/**
 * @title DeploymentArtifacts
 * @author Pacto
 * @notice Writes JSON under `deployments/<chainId>/` when running `forge script` (not `forge test`).
 */
abstract contract DeploymentArtifacts is Script {
  function _shouldWriteDeploymentJson() internal view returns (bool) {
    return vm.isContext(VmSafe.ForgeContext.ScriptDryRun) || vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)
      || vm.isContext(VmSafe.ForgeContext.ScriptResume);
  }

  function _deploymentJsonPath(string memory filename) internal view returns (string memory) {
    return string.concat('deployments/', vm.toString(block.chainid), '/', filename);
  }

  function _writeDeploymentJson(string memory json, string memory filename) internal {
    vm.createDir(string.concat('deployments/', vm.toString(block.chainid)), true);
    vm.writeJson(json, _deploymentJsonPath(filename));
  }

  function _writeFullSystemJson(
    address entryPoint,
    address navePirataRegistry,
    address squadSponsorFactory,
    address pactoSponsorPaymaster,
    address deployer
  ) internal {
    if (!_shouldWriteDeploymentJson()) return;
    string memory k = 'sponsor_full_system';
    vm.serializeUint(k, 'chainId', block.chainid);
    vm.serializeAddress(k, 'entryPoint', entryPoint);
    vm.serializeAddress(k, 'navePirataRegistry', navePirataRegistry);
    vm.serializeAddress(k, 'squadSponsorFactory', squadSponsorFactory);
    vm.serializeAddress(k, 'pactoSponsorPaymaster', pactoSponsorPaymaster);
    string memory json = vm.serializeAddress(k, 'deployer', deployer);
    _writeDeploymentJson(json, 'full-system.json');
  }
}
