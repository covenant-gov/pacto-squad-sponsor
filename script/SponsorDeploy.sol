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
 */
abstract contract SponsorDeploy is Script, DeploymentArtifacts {
  struct DeployAddresses {
    address factory;
    address paymaster;
  }

  SquadSponsorFactory internal _factory;
  PactoSponsorPaymaster internal _paymaster;
  DeployAddresses internal _deployAddrs;
  Constants.ChainConfig internal _config;

  /// @dev Override when a non-default CREATE2 salt is required.
  function _deploySaltFactory() internal view virtual returns (bytes32 saltFactory) {
    saltFactory = vm.envOr('SPONSOR_FACTORY_SALT', bytes32(0));
  }

  /// @notice Full chain bootstrap: CREATE2 factory; paymaster is deployed inside the factory constructor.
  function _deployFullSystem(address entryPoint, bytes32 saltFactory, address deployer) internal virtual {
    bytes32 _initCodeHash = _factoryInitCodeHash(entryPoint);
    address _predictedFactory = vm.computeCreate2Address(saltFactory, _initCodeHash, deployer);
    address _predictedPaymaster = vm.computeCreateAddress(_predictedFactory, 1);

    _factory = new SquadSponsorFactory{salt: saltFactory}(IEntryPoint(entryPoint));
    _paymaster = PactoSponsorPaymaster(payable(_factory.PAYMASTER()));

    require(address(_factory) == _predictedFactory, 'factory address mismatch');
    require(address(_paymaster) == _predictedPaymaster, 'paymaster address mismatch');

    _deployAddrs = DeployAddresses({factory: address(_factory), paymaster: address(_paymaster)});
  }

  function _factoryInitCodeHash(address entryPoint) internal pure returns (bytes32 initCodeHash) {
    initCodeHash =
      keccak256(abi.encodePacked(type(SquadSponsorFactory).creationCode, abi.encode(IEntryPoint(entryPoint))));
  }

  function _logDeployment() internal view virtual {
    console.log('SquadSponsorFactory:', address(_factory));
    console.log('PactoSponsorPaymaster:', address(_paymaster));
    console.log('Factory PAYMASTER:', _factory.PAYMASTER());
    console.log('Hats:', _factory.hats());
    console.log('NavePirataRegistry:', _config.navePirataRegistry);
  }

  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }
}
