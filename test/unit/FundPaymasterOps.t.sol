// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {FundPaymasterOps} from 'script/FundPaymasterOps.s.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IStakeManager} from '@account-abstraction/interfaces/IStakeManager.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

import {Test} from 'forge-std/Test.sol';

/**
 * @title FundPaymasterOpsHarness
 * @notice Exposes skip predicates and non-broadcast funding for unit coverage.
 */
contract FundPaymasterOpsHarness is FundPaymasterOps {
  function fund(
    ISquadSponsorFactory factory,
    PactoSponsorPaymaster paymaster,
    IEntryPoint ep,
    uint256 depositWei,
    uint256 stakeWei,
    uint256 unstakeDelaySec
  ) external {
    _fund(factory, paymaster, ep, depositWei, stakeWei, unstakeDelaySec, false);
  }

  function shouldSkipDeposit(uint256 currentDeposit, uint256 targetDeposit) external pure returns (bool) {
    return _shouldSkipDeposit(currentDeposit, targetDeposit);
  }

  function shouldSkipStake(IStakeManager.DepositInfo memory info, uint32 requestedDelay) external pure returns (bool) {
    return _shouldSkipStake(info, requestedDelay);
  }
}

/// @dev Minimal EntryPoint surface for paymaster `deposit` / `addStake` and skip reads.
contract EntryPointFundStub {
  mapping(address account => uint256 amount) public balanceOf;
  mapping(address account => IStakeManager.DepositInfo info) internal _info;

  function getDepositInfo(address account) external view returns (IStakeManager.DepositInfo memory info) {
    info = _info[account];
  }

  function setBalance(address account, uint256 amount) external {
    balanceOf[account] = amount;
  }

  function setStake(address account, bool staked, uint112 stake, uint32 unstakeDelaySec, uint48 withdrawTime) external {
    _info[account] = IStakeManager.DepositInfo({
      deposit: balanceOf[account],
      staked: staked,
      stake: stake,
      unstakeDelaySec: unstakeDelaySec,
      withdrawTime: withdrawTime
    });
  }

  function depositTo(address account) external payable {
    balanceOf[account] += msg.value;
  }

  function addStake(uint32 unstakeDelaySec) external payable {
    IStakeManager.DepositInfo storage info = _info[msg.sender];
    info.staked = true;
    info.stake += uint112(msg.value);
    info.unstakeDelaySec = unstakeDelaySec;
    info.withdrawTime = 0;
  }

  function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
    return interfaceId == type(IEntryPoint).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}

/**
 * @title UnitFundPaymasterOps
 * @author Pacto
 * @notice Unit tests for FundPaymasterOps skip-if-already-funded behavior.
 */
contract UnitFundPaymasterOps is Test {
  uint256 internal constant _DEPOSIT_WEI = 0.1 ether;
  uint256 internal constant _STAKE_WEI = 0.1 ether;
  uint32 internal constant _DELAY = 172_800;

  EntryPointFundStub internal _ep;
  SquadSponsorFactory internal _factory;
  PactoSponsorPaymaster internal _paymaster;
  FundPaymasterOpsHarness internal _harness;

  function setUp() public {
    _ep = new EntryPointFundStub();
    _factory = new SquadSponsorFactory(IEntryPoint(address(_ep)), address(0), address(this));
    _paymaster = PactoSponsorPaymaster(payable(_factory.PAYMASTER()));
    _harness = new FundPaymasterOpsHarness();
    vm.deal(address(_harness), 1 ether);
  }

  function test_Unit_FundPaymaster_SkipDepositWhenAtTarget() external view {
    assertTrue(_harness.shouldSkipDeposit(_DEPOSIT_WEI, _DEPOSIT_WEI));
    assertFalse(_harness.shouldSkipDeposit(_DEPOSIT_WEI - 1, _DEPOSIT_WEI));
  }

  function test_Unit_FundPaymaster_SkipStakeWhenLockedAtDelay() external view {
    IStakeManager.DepositInfo memory _locked = IStakeManager.DepositInfo({
      deposit: _DEPOSIT_WEI, staked: true, stake: uint112(_STAKE_WEI), unstakeDelaySec: _DELAY, withdrawTime: 0
    });
    IStakeManager.DepositInfo memory _unlocking = IStakeManager.DepositInfo({
      deposit: _DEPOSIT_WEI, staked: true, stake: uint112(_STAKE_WEI), unstakeDelaySec: _DELAY, withdrawTime: 1
    });
    IStakeManager.DepositInfo memory _vacant;

    assertTrue(_harness.shouldSkipStake(_locked, _DELAY));
    assertFalse(_harness.shouldSkipStake(_unlocking, _DELAY));
    assertFalse(_harness.shouldSkipStake(_vacant, _DELAY));
  }

  function test_Unit_FundPaymaster_BothAlreadyFundedSkipsCalls() external {
    _ep.setBalance(address(_paymaster), _DEPOSIT_WEI);
    _ep.setStake(address(_paymaster), true, uint112(_STAKE_WEI), _DELAY, 0);

    vm.expectCall(address(_paymaster), abi.encodeWithSelector(_paymaster.deposit.selector), 0);
    vm.expectCall(address(_factory), abi.encodeWithSelector(_factory.addPaymasterStake.selector, _DELAY), 0);

    _harness.fund(_factory, _paymaster, IEntryPoint(address(_ep)), _DEPOSIT_WEI, _STAKE_WEI, _DELAY);

    assertEq(_ep.balanceOf(address(_paymaster)), _DEPOSIT_WEI);
    assertEq(_factory.paymasterStaker(), address(0));
  }

  function test_Unit_FundPaymaster_DepositShortStakeLockedOnlyDeposits() external {
    _ep.setStake(address(_paymaster), true, uint112(_STAKE_WEI), _DELAY, 0);

    vm.expectCall(address(_paymaster), _DEPOSIT_WEI, abi.encodeWithSelector(_paymaster.deposit.selector));
    vm.expectCall(address(_factory), abi.encodeWithSelector(_factory.addPaymasterStake.selector, _DELAY), 0);

    _harness.fund(_factory, _paymaster, IEntryPoint(address(_ep)), _DEPOSIT_WEI, _STAKE_WEI, _DELAY);

    assertEq(_ep.balanceOf(address(_paymaster)), _DEPOSIT_WEI);
    assertEq(_factory.paymasterStaker(), address(0));
  }

  function test_Unit_FundPaymaster_DepositOkStakeVacantOnlyStakes() external {
    _ep.setBalance(address(_paymaster), _DEPOSIT_WEI);

    vm.expectCall(address(_paymaster), abi.encodeWithSelector(_paymaster.deposit.selector), 0);
    vm.expectCall(address(_factory), _STAKE_WEI, abi.encodeWithSelector(_factory.addPaymasterStake.selector, _DELAY));

    _harness.fund(_factory, _paymaster, IEntryPoint(address(_ep)), _DEPOSIT_WEI, _STAKE_WEI, _DELAY);

    assertEq(_ep.balanceOf(address(_paymaster)), _DEPOSIT_WEI);
    assertEq(_factory.paymasterStaker(), address(_harness));
    IStakeManager.DepositInfo memory _info = _ep.getDepositInfo(address(_paymaster));
    assertTrue(_info.staked);
    assertEq(_info.unstakeDelaySec, _DELAY);
    assertEq(_info.withdrawTime, 0);
  }

  function test_Unit_FundPaymaster_BothVacantFundsDepositAndStake() external {
    vm.expectCall(address(_paymaster), _DEPOSIT_WEI, abi.encodeWithSelector(_paymaster.deposit.selector));
    vm.expectCall(address(_factory), _STAKE_WEI, abi.encodeWithSelector(_factory.addPaymasterStake.selector, _DELAY));

    _harness.fund(_factory, _paymaster, IEntryPoint(address(_ep)), _DEPOSIT_WEI, _STAKE_WEI, _DELAY);

    assertEq(_ep.balanceOf(address(_paymaster)), _DEPOSIT_WEI);
    assertEq(_factory.paymasterStaker(), address(_harness));
    IStakeManager.DepositInfo memory _info = _ep.getDepositInfo(address(_paymaster));
    assertTrue(_info.staked);
    assertEq(uint256(_info.stake), _STAKE_WEI);
    assertEq(_info.unstakeDelaySec, _DELAY);
  }
}
