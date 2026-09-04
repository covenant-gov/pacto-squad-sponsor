// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {IPactoSponsorPaymaster} from 'interfaces/IPactoSponsorPaymaster.sol';
import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';
import {ISquadSponsorPool} from 'interfaces/ISquadSponsorPool.sol';

import {BasePaymaster} from '@account-abstraction/core/BasePaymaster.sol';
import {SIG_VALIDATION_FAILED} from '@account-abstraction/core/Helpers.sol';
import {UserOperationLib} from '@account-abstraction/core/UserOperationLib.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

/**
 * @title PactoSponsorPaymaster
 * @author Pacto
 * @notice ERC-4337 paymaster that validates squad clone registry, pool slot, spendable pool headroom, and eligibility.
 * @dev `paymasterAndData` layout (after standard 52-byte header): `abi.encode(uint8 version, PaymasterData)`.
 *      EIP-7702 senders must bind `sender == member` and delegate to `ALLOWED_7702_IMPLEMENTATION` (registry-backed).
 */
contract PactoSponsorPaymaster is IPactoSponsorPaymaster, BasePaymaster {
  using UserOperationLib for PackedUserOperation;

  /// @inheritdoc IPactoSponsorPaymaster
  uint8 public constant PAYMASTER_DATA_VERSION = 1;
  /// @notice Pool balance headroom required vs `maxCost` (115%).
  uint256 internal constant _BALANCE_HEADROOM_BPS = 11_500;
  /// @notice EIP-7702 designated-code prefix (`0xef0100`) length including the 20-byte implementation.
  uint256 internal constant _EIP7702_CODE_LENGTH = 23;
  /// @notice EIP-7702 designated-code magic prefix.
  bytes3 internal constant _EIP7702_PREFIX = 0xef0100;

  /// @inheritdoc IPactoSponsorPaymaster
  IPactoProtocolRegistry public immutable REGISTRY;
  /// @notice Factory used to anti-spoof squad clone addresses.
  ISquadSponsorFactory internal immutable _FACTORY;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Wires EntryPoint, squad factory, and protocol registry for the EIP-7702 allowlist.
   * @param entryPoint ERC-4337 EntryPoint v0.7 for this chain.
   * @param factory_ Squad sponsor factory singleton.
   * @param registry Username-system `PactoProtocolRegistry` (same instance as the global paymaster).
   */
  constructor(
    IEntryPoint entryPoint,
    ISquadSponsorFactory factory_,
    IPactoProtocolRegistry registry
  ) BasePaymaster(entryPoint) {
    if (address(factory_) == address(0)) revert SS_ZeroAddress();
    if (address(registry) == address(0)) revert SS_ZeroAddress();
    _FACTORY = factory_;
    REGISTRY = registry;
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IPactoSponsorPaymaster
  function ALLOWED_7702_IMPLEMENTATION() public view returns (address implementation) {
    implementation = REGISTRY.allowed7702Implementation();
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @notice Accepts ETH refunded from squad pools after `spendGas`.
  receive() external payable {}

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc BasePaymaster
  function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256) internal override {
    if (mode != PostOpMode.opSucceeded) return;

    address _pool = abi.decode(context, (address));
    ISquadSponsorPool(_pool).spendGas(actualGasCost);
  }

  /// @inheritdoc BasePaymaster
  function _validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32,
    uint256 maxCost
  ) internal view override returns (bytes memory context, uint256 validationData) {
    PaymasterData memory _data = _parsePaymasterData(userOp.paymasterAndData);
    _validateRegistry(_data);

    address _pool = ISquadSponsorBase(_data.sponsor).pool();
    if (ISquadSponsorPool(_pool).defacto() != _data.sponsor && ISquadSponsorPool(_pool).wargame() != _data.sponsor) {
      revert SS_SponsorNotInPoolSlot(_data.sponsor);
    }

    uint256 _requiredBalance = (maxCost * _BALANCE_HEADROOM_BPS) / 10_000;
    if (ISquadSponsorPool(_pool).spendablePoolWei() < _requiredBalance) {
      return ('', SIG_VALIDATION_FAILED);
    }

    if (!_isEligible(userOp.getSender(), _data)) {
      return ('', SIG_VALIDATION_FAILED);
    }

    context = abi.encode(_pool);
    validationData = 0;
  }

  /**
   * @notice Ensures the sponsor clone matches the factory registry for `squadId`.
   * @param data Parsed paymaster payload.
   */
  function _validateRegistry(PaymasterData memory data) internal view {
    ISquadSponsorFactory.SquadRecord memory _record = _FACTORY.squads(data.squadId);
    if (_record.sponsor != data.sponsor) {
      revert SS_CloneMismatch(data.squadId);
    }
  }

  /**
   * @notice Resolves eligibility and validates the member account binding.
   * @param sender `userOp.sender` (EOA, EIP-7702-delegated EOA, or other smart account).
   * @param data Parsed paymaster payload.
   * @return eligible True when the member may be sponsored.
   */
  function _isEligible(address sender, PaymasterData memory data) internal view returns (bool eligible) {
    if (data.member == address(0)) return false;

    bytes memory _code = sender.code;
    if (_code.length == 0) {
      if (sender != data.member) revert SS_InvalidMemberBinding(sender, data.member);
    } else if (_isEip7702Delegation(_code)) {
      if (sender != data.member) revert SS_InvalidMemberBinding(sender, data.member);
      address _impl = _eip7702Implementation(_code);
      if (_impl != ALLOWED_7702_IMPLEMENTATION()) revert SS_Invalid7702Implementation(_impl);
    }

    eligible = ISquadSponsorBase(data.sponsor).isEligible(data.member);
  }

  /**
   * @notice True when `code` is an EIP-7702 delegation stub (`0xef0100 || address`).
   * @param code Account bytecode.
   * @return isDelegation Whether the code matches the 23-byte designated format.
   */
  function _isEip7702Delegation(bytes memory code) internal pure returns (bool isDelegation) {
    return code.length == _EIP7702_CODE_LENGTH && bytes3(code) == _EIP7702_PREFIX;
  }

  /**
   * @notice Extracts the implementation address from an EIP-7702 delegation stub.
   * @param code 23-byte designated code (`0xef0100 || implementation`).
   * @return implementation Delegated contract address.
   */
  function _eip7702Implementation(bytes memory code) internal pure returns (address implementation) {
    // code layout: [0..2]=0xef0100, [3..22]=implementation. Skip length word + 3-byte prefix.
    assembly ('memory-safe') {
      implementation := shr(96, mload(add(code, 35)))
    }
  }

  /**
   * @notice Decodes squad payload from `paymasterAndData`.
   * @param paymasterAndData Full ERC-4337 paymaster field.
   * @return data Parsed squad payload.
   */
  function _parsePaymasterData(bytes calldata paymasterAndData) internal pure returns (PaymasterData memory data) {
    bytes calldata _payload = paymasterAndData[UserOperationLib.PAYMASTER_DATA_OFFSET:];
    uint8 _version;
    (_version, data.squadId, data.sponsor, data.member) = abi.decode(_payload, (uint8, bytes32, address, address));
    if (_version != PAYMASTER_DATA_VERSION) revert SS_InvalidVersion(_version);
  }
}
