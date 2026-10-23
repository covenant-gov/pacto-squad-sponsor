// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {PactoSimple7702Account} from 'pacto-aa/contracts/PactoSimple7702Account.sol';

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

import {SponsorDeploy} from 'script/SponsorDeploy.sol';

import {Test} from 'forge-std/Test.sol';

/**
 * @title SponsorDeployHarness
 * @notice Exposes live allowlist prechecks with forced live-script semantics for unit coverage.
 */
contract SponsorDeployHarness is SponsorDeploy {
  address internal _allowedOverride;
  address internal _registryOverride;
  address internal _adminOverride = address(this);

  function setOverrides(address allowed7702, address registry) external {
    _allowedOverride = allowed7702;
    _registryOverride = registry;
  }

  function assertLiveAllowlistAgreement(address entryPoint, address allowed7702, address registry) external view {
    _assertLiveAllowlistAgreement(entryPoint, allowed7702, registry);
  }

  function deployFullSystem(address entryPoint, bytes32 saltFactory) external {
    _deployFullSystem(entryPoint, saltFactory, address(this));
  }

  function paymaster() external view returns (address) {
    return address(_paymaster);
  }

  function _requireNonZeroOnLiveScript() internal pure override returns (bool) {
    return true;
  }

  function _resolveAllowed7702ForDeploy() internal view override returns (address allowed7702) {
    allowed7702 = _allowedOverride;
  }

  function _resolveAllowlistAdminForDeploy() internal view override returns (address admin) {
    admin = _adminOverride;
  }

  function _protocolRegistryAddress() internal view override returns (address registry) {
    registry = _registryOverride;
    if (registry == address(0)) revert SponsorDeploy_ZeroProtocolRegistry();
  }
}

/**
 * @title UnitSponsorDeployPrecheck
 * @author Pacto
 * @notice Unit tests for pre-CREATE2 allowlist agreement checks.
 */
contract UnitSponsorDeployPrecheck is Test {
  /// @dev Must match `PactoSimple7702Account`'s hardcoded EntryPoint v0.7.
  address internal constant _ENTRY_POINT = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
  address internal constant _REGISTRY = address(uint160(uint256(keccak256('pacto.sponsor.PROTOCOL_REGISTRY'))));

  SponsorDeployHarness internal _harness;
  PactoSimple7702Account internal _account;

  function setUp() public {
    vm.etch(_ENTRY_POINT, hex'00');
    vm.mockCall(
      _ENTRY_POINT,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IEntryPoint).interfaceId),
      abi.encode(true)
    );

    _account = new PactoSimple7702Account();
    _harness = new SponsorDeployHarness();
    _harness.setOverrides(address(_account), _REGISTRY);

    vm.mockCall(
      _REGISTRY,
      abi.encodeWithSelector(IPactoProtocolRegistry.allowed7702Implementation.selector),
      abi.encode(address(_account))
    );
  }

  function test_Unit_SponsorDeploy_PrecheckPassesWhenArtifactMatchesRegistry() external view {
    _harness.assertLiveAllowlistAgreement(_ENTRY_POINT, address(_account), _REGISTRY);
  }

  function test_Unit_SponsorDeploy_PrecheckRevertsEmptyCode() external {
    address _empty = makeAddr('empty7702');
    vm.expectRevert(abi.encodeWithSelector(SponsorDeploy.SponsorDeploy_Empty7702Code.selector, _empty));
    _harness.assertLiveAllowlistAgreement(_ENTRY_POINT, _empty, _REGISTRY);
  }

  function test_Unit_SponsorDeploy_PrecheckRevertsRegistryMismatch() external {
    address _other = makeAddr('otherAllowlist');
    vm.mockCall(
      _REGISTRY, abi.encodeWithSelector(IPactoProtocolRegistry.allowed7702Implementation.selector), abi.encode(_other)
    );

    vm.expectRevert(
      abi.encodeWithSelector(SponsorDeploy.SponsorDeploy_AllowlistMismatch.selector, address(_account), _other)
    );
    _harness.assertLiveAllowlistAgreement(_ENTRY_POINT, address(_account), _REGISTRY);
  }

  function test_Unit_SponsorDeploy_PrecheckRevertsEntryPointMismatch() external {
    address _wrongEp = makeAddr('wrongEntryPoint');
    vm.expectRevert(
      abi.encodeWithSelector(SponsorDeploy.SponsorDeploy_7702EntryPointMismatch.selector, _ENTRY_POINT, _wrongEp)
    );
    _harness.assertLiveAllowlistAgreement(_wrongEp, address(_account), _REGISTRY);
  }

  function test_Unit_SponsorDeploy_DeployFullSystemRunsPrecheckBeforeCreate2() external {
    address _empty = makeAddr('empty7702');
    _harness.setOverrides(_empty, _REGISTRY);

    vm.expectRevert(abi.encodeWithSelector(SponsorDeploy.SponsorDeploy_Empty7702Code.selector, _empty));
    _harness.deployFullSystem(_ENTRY_POINT, bytes32(0));
  }

  function test_Unit_SponsorDeploy_DeployFullSystemSucceedsWhenAgreementHolds() external {
    _harness.deployFullSystem(_ENTRY_POINT, bytes32(uint256(1)));
    PactoSponsorPaymaster _pm = PactoSponsorPaymaster(payable(_harness.paymaster()));
    assertEq(_pm.ALLOWED_7702_IMPLEMENTATION(), address(_account));
    assertEq(_pm.ALLOWLIST_ADMIN(), address(_harness));
  }
}
