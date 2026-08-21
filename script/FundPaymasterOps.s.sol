// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/**
 * @title FundPaymasterOps
 * @author Pacto
 * @notice Funds an already-deployed paymaster: EntryPoint deposit + FCFS `addPaymasterStake`.
 * @dev Reads `deployments/<chainId>/full-system.json`. Does **not** redeploy factory/paymaster
 *      and does **not** rewrite the artifact. Use `CutoverPaymasterOps` only when the live
 *      paymaster has a zero/wrong 7702 allowlist.
 *
 *      Env (optional funding knobs):
 *      - `PAYMASTER_EP_DEPOSIT_WEI` (default 0.1 ether)
 *      - `PAYMASTER_STAKE_WEI` (default 0.1 ether)
 *      - `PAYMASTER_UNSTAKE_DELAY_SEC` (default 172800 / 2 days)
 *
 *      Occupied FCFS stake slot: `addPaymasterStake` reverts `SS_StakeSlotOccupied` unless the
 *      broadcaster already holds it (top-up).
 */
contract FundPaymasterOps is DeploymentArtifacts {
  using stdJson for string;

  uint256 internal constant _DEFAULT_DEPOSIT_WEI = 0.1 ether;
  uint256 internal constant _DEFAULT_STAKE_WEI = 0.1 ether;
  uint256 internal constant _DEFAULT_UNSTAKE_DELAY_SEC = 172_800;

  function run() external {
    string memory _json = vm.readFile(_deploymentJsonPath('full-system.json'));
    address _entryPointAddr = _json.readAddress('.entryPoint');
    ISquadSponsorFactory _factory = ISquadSponsorFactory(_json.readAddress('.squadSponsorFactory'));
    PactoSponsorPaymaster _paymaster = PactoSponsorPaymaster(payable(_json.readAddress('.pactoSponsorPaymaster')));

    require(_factory.PAYMASTER() == address(_paymaster), 'fund: factory PAYMASTER mismatch');
    require(address(_paymaster.entryPoint()) == _entryPointAddr, 'fund: paymaster EP mismatch');

    uint256 _depositWei = vm.envOr('PAYMASTER_EP_DEPOSIT_WEI', _DEFAULT_DEPOSIT_WEI);
    uint256 _stakeWei = vm.envOr('PAYMASTER_STAKE_WEI', _DEFAULT_STAKE_WEI);
    uint256 _unstakeDelaySec = vm.envOr('PAYMASTER_UNSTAKE_DELAY_SEC', _DEFAULT_UNSTAKE_DELAY_SEC);
    require(_depositWei > 0, 'fund: zero deposit');
    require(_stakeWei > 0, 'fund: zero stake');
    require(_unstakeDelaySec <= type(uint32).max, 'fund: unstake delay overflow');

    IEntryPoint _ep = IEntryPoint(_entryPointAddr);
    uint256 _depositBefore = _ep.balanceOf(address(_paymaster));

    vm.startBroadcast();
    address _broadcaster = _broadcastDeployer();
    _paymaster.deposit{value: _depositWei}();
    _factory.addPaymasterStake{value: _stakeWei}(uint32(_unstakeDelaySec)); // forge-lint: disable-line(unsafe-typecast)
    vm.stopBroadcast();

    require(_ep.balanceOf(address(_paymaster)) >= _depositBefore + _depositWei, 'fund: EP deposit too low');
    require(_factory.paymasterStaker() == _broadcaster, 'fund: paymasterStaker mismatch');

    console.log('SquadSponsorFactory:', address(_factory));
    console.log('PactoSponsorPaymaster:', address(_paymaster));
    console.log('EntryPoint:', _entryPointAddr);
    console.log('EP deposit added (wei):', _depositWei);
    console.log('EP deposit total (wei):', _ep.balanceOf(address(_paymaster)));
    console.log('Stake added (wei):', _stakeWei);
    console.log('Unstake delay (sec):', _unstakeDelaySec);
    console.log('paymasterStaker:', _factory.paymasterStaker());
  }

  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }
}
