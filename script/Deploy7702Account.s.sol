// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSimple7702Account} from 'contracts/PactoSimple7702Account.sol';

import {Constants} from 'script/Constants.sol';
import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {console} from 'forge-std/console.sol';

/**
 * @title Deploy7702Account
 * @author Pacto
 * @notice CREATE2-deploys `PactoSimple7702Account` and writes `deployments/<chainId>/eip7702-account.json`.
 * @dev Salt: `PACTO_7702_ACCOUNT_SALT` (default `bytes32(0)`). Deploy before full-system so
 *      `PACTO_7702_ACCOUNT` can be passed into `SquadSponsorFactory` / paymaster allowlist.
 */
contract Deploy7702Account is DeploymentArtifacts {
  function run() external {
    Constants.ChainConfig memory _config = Constants.getConfig(block.chainid);
    bytes32 _salt = vm.envOr('PACTO_7702_ACCOUNT_SALT', bytes32(0));
    address _deployer = Constants.create2Deployer();

    bytes32 _initCodeHash = keccak256(type(PactoSimple7702Account).creationCode);
    address _predicted = vm.computeCreate2Address(_salt, _initCodeHash, _deployer);

    vm.startBroadcast();
    address _broadcaster = _broadcastDeployer();
    PactoSimple7702Account _account = new PactoSimple7702Account{salt: _salt}();
    vm.stopBroadcast();

    require(address(_account) == _predicted, '7702 account address mismatch');

    console.log('PactoSimple7702Account:', address(_account));
    console.log('EntryPoint:', _config.entryPoint);
    console.log('Salt:');
    console.logBytes32(_salt);

    _writeEip7702AccountJson(_config.entryPoint, address(_account), _salt, _broadcaster);
  }

  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }
}
