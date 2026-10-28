// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';

import {DeploymentArtifacts} from 'script/DeploymentArtifacts.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IStakeManager} from '@account-abstraction/interfaces/IStakeManager.sol';

import {stdJson} from 'forge-std/StdJson.sol';
import {console2} from 'forge-std/console2.sol';

/**
 * @title FundPaymasterOps
 * @author Pacto
 * @notice Funds an already-deployed paymaster: EntryPoint deposit + FCFS `addPaymasterStake`.
 * @dev Reads `deployments/<chainId>/full-system.json`. Does **not** redeploy factory/paymaster
 *      and does **not** rewrite the artifact. Use `CutoverPaymasterOps` only when the live
 *      paymaster has a zero/wrong 7702 allowlist.
 *
 *      Skip independently per side (no-op re-run, same idea as gov wire):
 *      - Deposit: skip when `balanceOf(paymaster) >= PAYMASTER_EP_DEPOSIT_WEI`.
 *      - Stake: skip when already locked at the requested unstake delay
 *        (`staked && unstakeDelaySec >= requested && withdrawTime == 0`).
 *      A short side still sends the env amount (not a deficit top-up). Both skip → no broadcast.
 *
 *      Env (optional funding knobs):
 *      - `PAYMASTER_EP_DEPOSIT_WEI` (default 0.1 ether)
 *      - `PAYMASTER_STAKE_WEI` (default 0.1 ether)
 *      - `PAYMASTER_UNSTAKE_DELAY_SEC` (default 172800 / 2 days)
 *
 *      Occupied FCFS stake slot: `addPaymasterStake` reverts `SS_StakeSlotOccupied` unless the
 *      broadcaster already holds it (top-up). Skip does not call it when stake is already locked.
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

    _fund(_factory, _paymaster, IEntryPoint(_entryPointAddr), _depositWei, _stakeWei, _unstakeDelaySec, true);
  }

  function _shouldSkipDeposit(uint256 currentDeposit, uint256 targetDeposit) internal pure returns (bool) {
    return currentDeposit >= targetDeposit;
  }

  function _shouldSkipStake(IStakeManager.DepositInfo memory info, uint32 requestedDelay) internal pure returns (bool) {
    return info.staked && info.unstakeDelaySec >= requestedDelay && info.withdrawTime == 0;
  }

  function _fund(
    ISquadSponsorFactory factory,
    PactoSponsorPaymaster paymaster,
    IEntryPoint ep,
    uint256 depositWei,
    uint256 stakeWei,
    uint256 unstakeDelaySec,
    bool withBroadcast
  ) internal {
    uint32 _delay = uint32(unstakeDelaySec); // forge-lint: disable-line(unsafe-typecast)
    bool _skipDeposit = _shouldSkipDeposit(ep.balanceOf(address(paymaster)), depositWei);
    bool _skipStake = _shouldSkipStake(ep.getDepositInfo(address(paymaster)), _delay);

    uint256 _depositAdded;
    uint256 _stakeAdded;
    if (!_skipDeposit || !_skipStake) {
      address _expectedStaker;
      if (withBroadcast) {
        vm.startBroadcast();
        _expectedStaker = _broadcastDeployer();
      } else {
        _expectedStaker = address(this);
      }

      if (!_skipDeposit) {
        paymaster.deposit{value: depositWei}();
        _depositAdded = depositWei;
      }
      if (!_skipStake) {
        factory.addPaymasterStake{value: stakeWei}(_delay);
        _stakeAdded = stakeWei;
      }

      if (withBroadcast) {
        vm.stopBroadcast();
      }
      if (!_skipStake) {
        require(factory.paymasterStaker() == _expectedStaker, 'fund: paymasterStaker mismatch');
      }
    }

    require(ep.balanceOf(address(paymaster)) >= depositWei, 'fund: EP deposit too low');
    if (_skipStake) {
      IStakeManager.DepositInfo memory _info = ep.getDepositInfo(address(paymaster));
      require(_info.staked && _info.unstakeDelaySec >= _delay && _info.withdrawTime == 0, 'fund: stake not locked');
    }

    if (_skipDeposit) {
      console2.log('EP deposit skipped (already >= target)');
    }
    if (_skipStake) {
      console2.log('Stake skipped (already locked at requested delay)');
    }
    console2.log('SquadSponsorFactory:', address(factory));
    console2.log('PactoSponsorPaymaster:', address(paymaster));
    console2.log('EntryPoint:', address(ep));
    console2.log('EP deposit added (wei):', _depositAdded);
    console2.log('EP deposit total (wei):', ep.balanceOf(address(paymaster)));
    console2.log('Stake added (wei):', _stakeAdded);
    console2.log('Unstake delay (sec):', unstakeDelaySec);
    console2.log('paymasterStaker:', factory.paymasterStaker());
  }

  function _broadcastDeployer() internal returns (address deployer) {
    (, deployer,) = vm.readCallers();
  }
}
