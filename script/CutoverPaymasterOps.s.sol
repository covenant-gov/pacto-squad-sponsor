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
 * @notice One-shot live-chain cutover: redeploy factory+paymaster wired to `PactoProtocolRegistry`,
 *         fund EntryPoint deposit + FCFS stake, write `full-system.json`.
 * @dev Does **not** redeploy `PactoSimple7702Account` (owned by pacto-aa). Resolve registry from
 *      mirrored `deployments/<chainId>/protocol-registry.json` or `PACTO_PROTOCOL_REGISTRY`.
 *      Day-2 EIP-7702 allowlist bumps use username `registry.set(Allowed7702Implementation, …)` —
 *      do **not** use this cutover for allowlist-only updates.
 *
 *      Env (optional funding knobs):
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

    address _registry = _protocolRegistryAddress();
    require(_registry != address(0), 'cutover: zero protocol registry');
    address _allowed7702 = IPactoProtocolRegistry(_registry).allowed7702Implementation();
    require(_allowed7702 != address(0), 'cutover: zero 7702 allowlist on registry');
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

    require(address(_paymaster.REGISTRY()) == _registry, 'cutover: REGISTRY mismatch');
    require(_paymaster.ALLOWED_7702_IMPLEMENTATION() == _allowed7702, 'cutover: allowlist mismatch');
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
    console.log('ALLOWED_7702_IMPLEMENTATION:', _allowed7702);
    console.log('EP deposit (wei):', _depositWei);
    console.log('Stake (wei):', _stakeWei);
    console.log('Unstake delay (sec):', _unstakeDelaySec);
    console.log('paymasterStaker:', _factory.paymasterStaker());

    _writeFullSystemJson(
      _config.entryPoint,
      _config.navePirataRegistry,
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
