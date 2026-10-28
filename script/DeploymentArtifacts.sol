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
  /// @dev Canonical artifact lives in pacto-aa; keep a copy here for forge allowlist assertions.
  function _readPactoSimple7702FromArtifact() internal view returns (address account) {
    try vm.readFile(_deploymentJsonPath('eip7702-account.json')) returns (string memory json) {
      account = json.readAddress('.pactoSimple7702Account');
    } catch {
      account = address(0);
    }
  }

  /// @notice Prefer mirrored pacto-aa `eip7702-account.json`, then `PACTO_7702_ACCOUNT` env.
  /// @dev Factory constructor seeds the paymaster allowlist. Live deploy asserts equality with the registry slot.
  function _resolveAllowed7702Implementation() internal view returns (address allowed7702) {
    allowed7702 = _readPactoSimple7702FromArtifact();
    if (allowed7702 != address(0)) return allowed7702;
    allowed7702 = vm.envOr('PACTO_7702_ACCOUNT', address(0));
  }

  /// @notice Reads `protocolRegistry` from mirrored `deployments/<chainId>/protocol-registry.json` when present.
  /// @dev Canonical address lives in pacto-username-nft `full-system.json`; keep a thin copy here for forge scripts.
  function _readProtocolRegistryFromArtifact() internal view returns (address registry) {
    try vm.readFile(_deploymentJsonPath('protocol-registry.json')) returns (string memory json) {
      registry = json.readAddress('.protocolRegistry');
    } catch {
      registry = address(0);
    }
  }

  /// @notice Prefer mirrored `protocol-registry.json`, then `PACTO_PROTOCOL_REGISTRY` env.
  function _resolveProtocolRegistry() internal view returns (address registry) {
    registry = _readProtocolRegistryFromArtifact();
    if (registry != address(0)) return registry;
    registry = vm.envOr('PACTO_PROTOCOL_REGISTRY', address(0));
  }

  /// @notice Optional gov `navePirataRegistry` from mirrored `protocol-registry.json` when present.
  /// @dev Canonical address lives in pacto-gov `full-system.json` / `infra.json`. This package does not deploy it.
  function _readNavePirataRegistryFromArtifact() internal view returns (address registry) {
    try vm.readFile(_deploymentJsonPath('protocol-registry.json')) returns (string memory json) {
      try vm.parseJsonAddress(json, '.navePirataRegistry') returns (address fromJson) {
        registry = fromJson;
      } catch {
        registry = address(0);
      }
    } catch {
      registry = address(0);
    }
  }

  /// @notice Prefer optional `protocol-registry.json` `.navePirataRegistry`, then `PACTO_NAVE_PIRATA_REGISTRY`.
  /// @dev Never fall back to `Constants.sol`. Zero means omit the key from `full-system.json`.
  function _resolveNavePirataRegistry() internal view returns (address registry) {
    registry = _readNavePirataRegistryFromArtifact();
    if (registry != address(0)) return registry;
    registry = vm.envOr('PACTO_NAVE_PIRATA_REGISTRY', address(0));
  }

  function _writeDeploymentJson(string memory json, string memory filename) internal {
    vm.createDir(string.concat('deployments/', vm.toString(block.chainid)), true);
    vm.writeJson(json, _deploymentJsonPath(filename));
  }

  function _writeFullSystemJson(
    address entryPoint,
    address protocolRegistry,
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
    address navePirataRegistry = _resolveNavePirataRegistry();
    if (navePirataRegistry != address(0)) {
      vm.serializeAddress(k, 'navePirataRegistry', navePirataRegistry);
    }
    vm.serializeAddress(k, 'protocolRegistry', protocolRegistry);
    vm.serializeAddress(k, 'squadSponsorFactory', squadSponsorFactory);
    vm.serializeAddress(k, 'pactoSponsorPaymaster', pactoSponsorPaymaster);
    vm.serializeAddress(k, 'sponsorImplementation', sponsorImplementation);
    vm.serializeAddress(k, 'extImplementation', extImplementation);
    vm.serializeAddress(k, 'poolImplementation', poolImplementation);
    string memory json = vm.serializeAddress(k, 'deployer', deployer);
    _writeDeploymentJson(json, 'full-system.json');
  }
}
