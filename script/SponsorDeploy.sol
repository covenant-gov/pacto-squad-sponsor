// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

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
 *      Factory ctor takes the EIP-7702 account address. That address is recorded as an immutable on the paymaster.
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
  address internal _allowed7702;

  /// @dev Override when a non-default CREATE2 salt is required.
  function _deploySaltFactory() internal view virtual returns (bytes32 saltFactory) {
    saltFactory = vm.envOr('SPONSOR_FACTORY_SALT', bytes32(0));
  }

  /// @notice Full chain bootstrap: CREATE2 factory; paymaster is deployed inside the factory constructor.
  function _deployFullSystem(address entryPoint, bytes32 saltFactory, address deployer) internal virtual {
    address _allowed = _allowed7702Address();
    address _registry = _protocolRegistryAddress();
    bytes32 _initCodeHash = _factoryInitCodeHash(entryPoint, _allowed);
    address _predictedFactory = vm.computeCreate2Address(saltFactory, _initCodeHash, deployer);
    address _predictedPaymaster = vm.computeCreateAddress(_predictedFactory, 1);

    _factory = new SquadSponsorFactory{salt: saltFactory}(IEntryPoint(entryPoint), _allowed);
    _paymaster = PactoSponsorPaymaster(payable(_factory.PAYMASTER()));
    _allowed7702 = _allowed;
    _protocolRegistry = _registry;

    require(address(_factory) == _predictedFactory, 'factory address mismatch');
    require(address(_paymaster) == _predictedPaymaster, 'paymaster address mismatch');

    _deployAddrs = DeployAddresses({factory: address(_factory), paymaster: address(_paymaster)});
  }

  /// @dev Artifact / `PACTO_7702_ACCOUNT`. Tests override `_resolveAllowed7702ForDeploy` to return `address(0)`.
  function _allowed7702Address() internal view virtual returns (address allowed7702) {
    allowed7702 = _resolveAllowed7702ForDeploy();
    if (allowed7702 == address(0) && _requireNonZeroOnLiveScript()) {
      revert SponsorDeploy_Zero7702Allowlist();
    }
  }

  /// @dev Prefer artifact/env; tests override to keep the allowlist unset.
  function _resolveAllowed7702ForDeploy() internal view virtual returns (address allowed7702) {
    allowed7702 = _resolveAllowed7702Implementation();
  }

  /// @dev Artifact / `PACTO_PROTOCOL_REGISTRY`. Recorded in `full-system.json`; not a factory constructor arg.
  ///      Tests do not override this. Live forge scripts reject `address(0)` so verify can read the artifact.
  function _protocolRegistryAddress() internal view virtual returns (address registry) {
    registry = _resolveProtocolRegistry();
    if (registry == address(0) && _requireNonZeroOnLiveScript()) {
      revert SponsorDeploy_ZeroProtocolRegistry();
    }
  }

  /// @dev Optional assertion helper: the paymaster immutable must be non-zero on public chains.
  function _assertLiveAllowed7702(address allowed7702) internal view {
    if (!_requireNonZeroOnLiveScript()) return;
    if (allowed7702 == address(0)) revert SponsorDeploy_Zero7702Allowlist();
  }

  /// @dev Enforce non-zero 7702 and protocol-registry artifact only for script broadcasts on public chains.
  function _requireNonZeroOnLiveScript() internal view virtual returns (bool) {
    uint256 chainId = block.chainid;
    if (chainId != 1 && chainId != 11_155_111 && chainId != 42_161) return false;
    return _isForgeScriptContext();
  }

  function _factoryInitCodeHash(address entryPoint, address allowed7702) internal pure returns (bytes32 initCodeHash) {
    initCodeHash = keccak256(
      abi.encodePacked(type(SquadSponsorFactory).creationCode, abi.encode(IEntryPoint(entryPoint), allowed7702))
    );
  }

  function _logDeployment() internal view virtual {
    console.log('SquadSponsorFactory:', address(_factory));
    console.log('PactoSponsorPaymaster:', address(_paymaster));
    console.log('ProtocolRegistry:', _protocolRegistry);
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
