// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Constants} from 'script/Constants.sol';
import {SponsorDeploy} from 'script/SponsorDeploy.sol';

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoSimple7702Account} from 'interfaces/IPactoSimple7702Account.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {console} from 'forge-std/console.sol';

/**
 * @title CutoverPaymasterOps
 * @author Pacto
 * @notice One-shot live-chain cutover: redeploy factory+paymaster with a seeded EIP-7702 allowlist,
 *         fund EntryPoint deposit + FCFS stake, write `full-system.json`.
 * @dev Does **not** redeploy `PactoSimple7702Account` (owned by pacto-aa). The factory constructor
 *      receives the account from `eip7702-account.json` / `PACTO_7702_ACCOUNT` and `ALLOWLIST_ADMIN`.
 *      The account must equal `PactoProtocolRegistry.allowed7702Implementation()` from
 *      `protocol-registry.json`. After deploy, `ALLOWLIST_ADMIN` can rotate the allowlist without
 *      recreating pools (the paymaster does not read the registry at validation time).
 *
 *      Env (optional funding knobs):
 *      - `ALLOWLIST_ADMIN` (required on live public chains)
 *      - `PAYMASTER_EP_DEPOSIT_WEI` (default 0.1 ether)
 *      - `PAYMASTER_STAKE_WEI` (default 0.1 ether)
 *      - `PAYMASTER_UNSTAKE_DELAY_SEC` (default 172800 / 2 days)
 *      - `SPONSOR_FACTORY_SALT` (default 0)
 */
contract CutoverPaymasterOps is SponsorDeploy {
  uint256 internal constant _DEFAULT_DEPOSIT_WEI = 0.1 ether;
  uint256 internal constant _DEFAULT_STAKE_WEI = 0.1 ether;
  uint256 internal constant _DEFAULT_UNSTAKE_DELAY_SEC = 172_800;

  function run() external {
    _config = Constants.getConfig(block.chainid);

    // Early fail before broadcast; `_deployFullSystem` repeats the same agreement checks pre-CREATE2.
    address _registry = _protocolRegistryAddress();
    require(_registry != address(0), 'cutover: zero protocol registry');
    address _registryAllowlist = IPactoProtocolRegistry(_registry).allowed7702Implementation();
    address _allowed7702 = _resolveAllowed7702Implementation();
    require(_allowed7702 != address(0), 'cutover: zero 7702 allowlist');
    require(_allowed7702 == _registryAllowlist, 'cutover: allowlist mismatch');
    require(
      address(IPactoSimple7702Account(_allowed7702).entryPoint()) == _config.entryPoint, 'cutover: 7702 EP mismatch'
    );

    uint256 _depositWei = vm.envOr('PAYMASTER_EP_DEPOSIT_WEI', _DEFAULT_DEPOSIT_WEI);
    uint256 _stakeWei = vm.envOr('PAYMASTER_STAKE_WEI', _DEFAULT_STAKE_WEI);
    uint256 _unstakeDelaySec = vm.envOr('PAYMASTER_UNSTAKE_DELAY_SEC', _DEFAULT_UNSTAKE_DELAY_SEC);
    require(_depositWei > 0, 'cutover: zero deposit');
    require(_stakeWei > 0, 'cutover: zero stake');

    vm.startBroadcast();
    address _broadcaster = _broadcastDeployer();
    _deployFullSystem(_config.entryPoint, _deploySaltFactory(), Constants.create2Deployer());

    require(_paymaster.ALLOWED_7702_IMPLEMENTATION() == _allowed7702, 'cutover: allowlist mismatch');
    require(_paymaster.ALLOWLIST_ADMIN() == _allowlistAdmin, 'cutover: allowlist admin mismatch');
    require(_factory.PAYMASTER() == address(_paymaster), 'cutover: factory PAYMASTER mismatch');
    require(address(_paymaster.entryPoint()) == _config.entryPoint, 'cutover: paymaster EP mismatch');

    _paymaster.deposit{value: _depositWei}();
    require(_unstakeDelaySec <= type(uint32).max, 'cutover: unstake delay overflow');
    _factory.addPaymasterStake{value: _stakeWei}(uint32(_unstakeDelaySec)); // forge-lint: disable-line(unsafe-typecast)
    vm.stopBroadcast();

    IEntryPoint _ep = IEntryPoint(_config.entryPoint);
    require(_ep.balanceOf(address(_paymaster)) >= _depositWei, 'cutover: EP deposit too low');
    require(_factory.paymasterStaker() == _broadcaster, 'cutover: paymasterStaker mismatch');

    _logDeployment();
    console.log('ProtocolRegistry:', _registry);
    console.log('ALLOWLIST_ADMIN:', _allowlistAdmin);
    console.log('ALLOWED_7702_IMPLEMENTATION:', _allowed7702);
    console.log('EP deposit (wei):', _depositWei);
    console.log('Stake (wei):', _stakeWei);
    console.log('Unstake delay (sec):', _unstakeDelaySec);
    console.log('paymasterStaker:', _factory.paymasterStaker());

    _writeFullSystemJson(
      _config.entryPoint,
      _registry,
      address(_factory),
      address(_paymaster),
      _factory.sponsorImplementation(),
      _factory.extImplementation(),
      _factory.poolImplementation(),
      _broadcaster
    );
  }
}
