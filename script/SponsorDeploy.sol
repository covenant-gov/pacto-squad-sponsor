// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

import {Constants} from 'script/Constants.sol';
import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

/**
 * @title SponsorDeploy
 * @author Pacto
 * @notice Shared CREATE2 deploy routine for `SquadSponsorFactory` (paymaster deployed in factory constructor).
 * @dev `forge script` entrypoints inherit this; integration tests inherit `IntegrationBase` for the same deploy path.
 *      CREATE2 deployer is `CREATE2_DEFAULT_DEPLOYER` in `forge script` (Foundry's Create2Deployer);
 *      integration tests pass `address(this)` because they deploy without broadcast.
 *      Paymaster address = first CREATE child of the factory (`nonce` 1).
 *      Factory ctor takes the username-system `PactoProtocolRegistry`; EIP-7702 allowlist is read live from it.
 */
abstract contract SponsorDeploy is Script, DeploymentArtifacts {
  error SponsorDeploy_ZeroProtocolRegistry();
  error SponsorDeploy_Zero7702Allowlist();

  struct DeployAddresses {
    address factory;
    address paymaster;
  }

  SquadSponsorFactory internal _factory;
  PactoSponsorPaymaster internal _paymaster;
  DeployAddresses internal _deployAddrs;
  Constants.ChainConfig internal _config;
  address internal _protocolRegistry;

  /// @dev Override when a non-default CREATE2 salt is required.
  function _deploySaltFactory() internal view virtual returns (bytes32 saltFactory) {
    saltFactory = vm.envOr('SPONSOR_FACTORY_SALT', bytes32(0));
  }

  /// @notice Full chain bootstrap: CREATE2 factory; paymaster is deployed inside the factory constructor.
  function _deployFullSystem(address entryPoint, bytes32 saltFactory, address deployer) internal virtual {
    address _registry = _protocolRegistryAddress();
    bytes32 _initCodeHash = _factoryInitCodeHash(entryPoint, _registry);
    address _predictedFactory = vm.computeCreate2Address(saltFactory, _initCodeHash, deployer);
    address _predictedPaymaster = vm.computeCreateAddress(_predictedFactory, 1);

    _factory = new SquadSponsorFactory{salt: saltFactory}(IEntryPoint(entryPoint), _registry);
    _paymaster = PactoSponsorPaymaster(payable(_factory.PAYMASTER()));
    _protocolRegistry = _registry;

    require(address(_factory) == _predictedFactory, 'factory address mismatch');
    require(address(_paymaster) == _predictedPaymaster, 'paymaster address mismatch');

    _deployAddrs = DeployAddresses({factory: address(_factory), paymaster: address(_paymaster)});
  }

  /// @dev Artifact / `PACTO_PROTOCOL_REGISTRY`; live-chain forge scripts reject `address(0)`.
  ///      Tests override `_resolveProtocolRegistryForDeploy` to return a mock registry.
  function _protocolRegistryAddress() internal view virtual returns (address registry) {
    registry = _resolveProtocolRegistryForDeploy();
    if (registry == address(0) && _requireNonZeroProtocolRegistry()) {
      revert SponsorDeploy_ZeroProtocolRegistry();
    }
  }

  /// @dev Prefer artifact/env; tests override to inject a mock.
  function _resolveProtocolRegistryForDeploy() internal view virtual returns (address registry) {
    registry = _resolveProtocolRegistry();
  }

  /// @dev Optional assertion helper: live registry slot should be non-zero on public chains.
  function _assertLiveRegistryAllowlist(address registry) internal view {
    if (!_requireNonZeroProtocolRegistry()) return;
    address _allowed7702 = IPactoProtocolRegistry(registry).allowed7702Implementation();
    if (_allowed7702 == address(0)) revert SponsorDeploy_Zero7702Allowlist();
  }

  /// @dev Enforce registry only for script broadcasts on production / public testnets.
  function _requireNonZeroProtocolRegistry() internal view virtual returns (bool) {
    uint256 chainId = block.chainid;
    if (chainId != 1 && chainId != 11_155_111 && chainId != 42_161) return false;
    return _isForgeScriptContext();
  }

  function _factoryInitCodeHash(
    address entryPoint,
    address protocolRegistry
  ) internal pure returns (bytes32 initCodeHash) {
    initCodeHash = keccak256(
      abi.encodePacked(type(SquadSponsorFactory).creationCode, abi.encode(IEntryPoint(entryPoint), protocolRegistry))
    );
  }

  function _logDeployment() internal view virtual {
    console.log('SquadSponsorFactory:', address(_factory));
    console.log('PactoSponsorPaymaster:', address(_paymaster));
    console.log('ProtocolRegistry:', address(_paymaster.REGISTRY()));
    console.log('ALLOWED_7702_IMPLEMENTATION:', _paymaster.ALLOWED_7702_IMPLEMENTATION());
    console.log('Sponsor implementation:', _factory.sponsorImplementation());
    console.log('Ext implementation:', _factory.extImplementation());
    console.log('Pool implementation:', _factory.poolImplementation());
    console.log('Factory PAYMASTER:', _factory.PAYMASTER());
    console.log('Hats:', _factory.hats());
    console.log('NavePirataRegistry:', _config.navePirataRegistry);
  }

  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }
}
