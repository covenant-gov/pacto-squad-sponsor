// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {VmSafe} from 'forge-std/Vm.sol';

/**
 * @title DeploymentArtifacts
 * @author Pacto
 * @notice Writes JSON under `deployments/<chainId>/` when running `forge script` (not `forge test`).
 */
abstract contract DeploymentArtifacts is Script {
  using stdJson for string;

  function _shouldWriteDeploymentJson() internal view returns (bool) {
    return vm.isContext(VmSafe.ForgeContext.ScriptDryRun) || vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)
      || vm.isContext(VmSafe.ForgeContext.ScriptResume);
  }

  function _isForgeScriptContext() internal view returns (bool) {
    return _shouldWriteDeploymentJson();
  }

  function _deploymentJsonPath(string memory filename) internal view returns (string memory) {
    return string.concat('deployments/', vm.toString(block.chainid), '/', filename);
  }

  /// @notice Reads `pactoSimple7702Account` from mirrored `deployments/<chainId>/eip7702-account.json` when present.
  /// @dev Canonical artifact lives in pacto-aa; keep a copy here for forge allowlist resolution.
  function _readPactoSimple7702FromArtifact() internal view returns (address account) {
    try vm.readFile(_deploymentJsonPath('eip7702-account.json')) returns (string memory json) {
      account = json.readAddress('.pactoSimple7702Account');
    } catch {
      account = address(0);
    }
  }

  /// @notice Prefer mirrored pacto-aa `eip7702-account.json`, then `PACTO_7702_ACCOUNT` env.
  function _resolveAllowed7702Implementation() internal view returns (address allowed7702) {
    allowed7702 = _readPactoSimple7702FromArtifact();
    if (allowed7702 != address(0)) return allowed7702;
    allowed7702 = vm.envOr('PACTO_7702_ACCOUNT', address(0));
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
    address sponsorImplementation,
    address extImplementation,
    address poolImplementation,
    address deployer
  ) internal {
    if (!_shouldWriteDeploymentJson()) return;
    string memory k = 'sponsor_full_system';
    vm.serializeUint(k, 'chainId', block.chainid);
    vm.serializeAddress(k, 'entryPoint', entryPoint);
    vm.serializeAddress(k, 'navePirataRegistry', navePirataRegistry);
    vm.serializeAddress(k, 'squadSponsorFactory', squadSponsorFactory);
    vm.serializeAddress(k, 'pactoSponsorPaymaster', pactoSponsorPaymaster);
    vm.serializeAddress(k, 'sponsorImplementation', sponsorImplementation);
    vm.serializeAddress(k, 'extImplementation', extImplementation);
    vm.serializeAddress(k, 'poolImplementation', poolImplementation);
    string memory json = vm.serializeAddress(k, 'deployer', deployer);
    _writeDeploymentJson(json, 'full-system.json');
  }
}
