// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {ISquadSponsorPool} from 'interfaces/ISquadSponsorPool.sol';

import {Constants, DEFAULT_MAINNET_FORK_BLOCK, HATS_PROTOCOL_V1} from 'script/Constants.sol';
import {SponsorDeploy} from 'script/SponsorDeploy.sol';

import {IPaymaster} from '@account-abstraction/interfaces/IPaymaster.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {Test} from 'forge-std/Test.sol';

import {MockProtocolRegistry} from 'test/unit/helpers/MockProtocolRegistry.sol';

/**
 * @title IntegrationBase
 * @author Pacto
 * @notice Runs the same deploy routine as `script/Deploy.sol` during `setUp`.
 * @dev Requires a mainnet fork: `pnpm test:integration` (`--fork-url mainnet --fork-block-number 22900000`)
 *      or `IntegrationBase` will `vm.createSelectFork` when Hats bytecode is absent. `MAINNET_RPC` must be set (see `.env.example`).
 *      Modifiers: `withDeployedExtSquad`, `withPermittedMember`, `withWiredExtSquad`, `withDeployedHatSponsor`.
 *      Use `_newExtClone()` / `_newSponsorClone()` for init / revert scenarios without factory registration.
 */
abstract contract IntegrationBase is SponsorDeploy, Test {
  error IntegrationBase_NoMainnetFork();

  uint256 internal constant _E2E_TOP_HAT_ID = 0xE2E0001;
  uint256 internal constant _E2E_CUSTOM_HAT_ID = 0xE2E0002;
  uint256 internal constant _E2E_POOL_DEPOSIT = 5 ether;

  bool internal _integrationForkActive;
  MockProtocolRegistry internal _mockRegistry;

  bytes32 internal _squadId;
  SquadSponsorExt internal _extSponsor;
  address internal _addressOwner;
  address internal _member;
  address internal _stranger;

  bytes32 internal _hatSquadId;
  SquadSponsor internal _hatSponsor;

  bool internal _fixtureHasExtSquad;
  bool internal _fixtureHasPermittedMember;
  bool internal _fixtureHasWiredExt;
  bool internal _fixtureHasHatSponsor;

  modifier withDeployedExtSquad() {
    _ensureExtSquad();
    _;
  }

  modifier withPermittedMember() {
    _ensureExtSquad();
    _ensurePermittedMember();
    _;
  }

  modifier withWiredExtSquad() {
    _ensureExtSquad();
    _ensureWiredExtSquad();
    _;
  }

  modifier withDeployedHatSponsor() {
    _ensureHatSponsorSquad();
    _;
  }

  function setUp() public virtual {
    _requireEthereumMainnetFork();
    _config = Constants.getConfig(block.chainid);
    _mockRegistry = new MockProtocolRegistry();
    _deployFullSystem(_config.entryPoint, _deploySaltFactory(), address(this));
    _stranger = makeAddr('e2eStranger');
    _fund(_stranger, 1 ether);
  }

  /// @dev Integration tests inject a mock registry (live username registry is not on mainnet fork fixtures).
  function _resolveProtocolRegistryForDeploy() internal view override returns (address registry) {
    registry = address(_mockRegistry);
  }

  function _requireEthereumMainnetFork() internal virtual {
    if (HATS_PROTOCOL_V1.code.length > 0) {
      _integrationForkActive = true;
      return;
    }
    string memory _rpc = vm.envOr('MAINNET_RPC', string(''));
    if (bytes(_rpc).length == 0) {
      try vm.rpcUrl('mainnet') returns (string memory _fromToml) {
        _rpc = _fromToml;
      } catch {}
    }
    if (bytes(_rpc).length == 0) revert IntegrationBase_NoMainnetFork();
    vm.createSelectFork(_rpc, DEFAULT_MAINNET_FORK_BLOCK);
    _integrationForkActive = true;
  }

  function _fund(address _who, uint256 _wei) internal virtual {
    vm.deal(_who, _wei);
  }

  function _freshSquadId() internal view virtual returns (bytes32 squadId) {
    squadId = keccak256(abi.encodePacked('pacto.e2e.sponsor', block.timestamp, address(this)));
  }

  function _newExtClone() internal virtual returns (SquadSponsorExt _fresh) {
    _fresh = SquadSponsorExt(payable(Clones.clone(_factory.extImplementation())));
  }

  function _newSponsorClone() internal virtual returns (SquadSponsor _fresh) {
    _fresh = SquadSponsor(payable(Clones.clone(_factory.sponsorImplementation())));
  }

  function _ensureExtSquad() internal virtual {
    if (_fixtureHasExtSquad) return;

    _squadId = _freshSquadId();
    _addressOwner = makeAddr('e2eAddressOwner');
    _fund(_addressOwner, 10 ether);

    vm.prank(_addressOwner);
    address _sponsor = _factory.createSquadSponsorExt{value: _E2E_POOL_DEPOSIT}(_squadId, _addressOwner);
    _extSponsor = SquadSponsorExt(payable(_sponsor));

    _fixtureHasExtSquad = true;
  }

  function _ensurePermittedMember() internal virtual {
    if (_fixtureHasPermittedMember) return;

    _member = makeAddr('e2ePermittedMember');
    vm.prank(_addressOwner);
    _extSponsor.setPermittedAddress(_member, true);

    _fixtureHasPermittedMember = true;
  }

  function _ensureWiredExtSquad() internal virtual {
    if (_fixtureHasWiredExt) return;

    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = _E2E_CUSTOM_HAT_ID;

    vm.prank(_addressOwner);
    _extSponsor.postInitialize(_E2E_TOP_HAT_ID, address(0), _customHats);

    _fixtureHasWiredExt = true;
  }

  function _ensureHatSponsorSquad() internal virtual {
    if (_fixtureHasHatSponsor) return;

    _hatSquadId = _freshSquadId();
    uint256[] memory _customHats = new uint256[](1);
    _customHats[0] = _E2E_CUSTOM_HAT_ID;

    _fund(address(this), 1 ether);
    address _sponsor =
      _factory.createSquadSponsor{value: 1 ether}(_hatSquadId, _E2E_TOP_HAT_ID, address(0), _customHats);
    _hatSponsor = SquadSponsor(payable(_sponsor));

    _fixtureHasHatSponsor = true;
  }

  function _mockHatWearer(address _wearer, uint256 _hatId, bool _isWearer) internal virtual {
    vm.mockCall(
      HATS_PROTOCOL_V1,
      abi.encodeWithSignature('isWearerOfHat(address,uint256)', _wearer, _hatId),
      abi.encode(_isWearer)
    );
  }

  function _mockHatsAdmin(address _admin, uint256 _topHatId, bool _isAdmin) internal virtual {
    vm.mockCall(
      HATS_PROTOCOL_V1,
      abi.encodeWithSignature('isAdminOfHat(address,uint256)', _admin, _topHatId),
      abi.encode(_isAdmin)
    );
  }

  function _buildUserOp(
    address _sender,
    bytes32 _squadId_,
    address _sponsor,
    address _member_
  ) internal view returns (PackedUserOperation memory _userOp) {
    bytes memory _payload = abi.encode(uint8(_paymaster.PAYMASTER_DATA_VERSION()), _squadId_, _sponsor, _member_);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    _userOp.sender = _sender;
    _userOp.paymasterAndData = bytes.concat(_header, _payload);
  }

  function _buildExtUserOp(
    address _sender,
    address _member_
  ) internal view returns (PackedUserOperation memory _userOp) {
    _userOp = _buildUserOp(_sender, _squadId, address(_extSponsor), _member_);
  }

  function _validatePaymaster(
    PackedUserOperation memory _userOp,
    uint256 _maxCost
  ) internal returns (bytes memory _context, uint256 _validationData) {
    vm.prank(_config.entryPoint);
    (_context, _validationData) = _paymaster.validatePaymasterUserOp(_userOp, bytes32(0), _maxCost);
  }

  function _postOpSucceeded(bytes memory _context, uint256 _actualGasCost) internal {
    vm.prank(_config.entryPoint);
    _paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, _context, _actualGasCost, 0);
  }

  function _postOpReverted(bytes memory _context, uint256 _actualGasCost) internal {
    vm.prank(_config.entryPoint);
    _paymaster.postOp(IPaymaster.PostOpMode.opReverted, _context, _actualGasCost, 0);
  }

  function _pool() internal view returns (ISquadSponsorPool _p) {
    _p = ISquadSponsorPool(_extSponsor.pool());
  }
}
