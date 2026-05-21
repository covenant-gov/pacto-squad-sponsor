// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPactoSponsorPaymaster} from 'interfaces/IPactoSponsorPaymaster.sol';
import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {BasePaymaster} from '@account-abstraction/core/BasePaymaster.sol';
import {SIG_VALIDATION_FAILED} from '@account-abstraction/core/Helpers.sol';
import {UserOperationLib} from '@account-abstraction/core/UserOperationLib.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

/**
 * @title PactoSponsorPaymaster
 * @author Pacto
 * @notice ERC-4337 paymaster that validates squad clone registry, pool balance, and eligibility.
 * @dev `paymasterAndData` layout (after standard 52-byte header): `abi.encode(uint8 version, PaymasterData)`.
 */
contract PactoSponsorPaymaster is IPactoSponsorPaymaster, BasePaymaster {
  using UserOperationLib for PackedUserOperation;

  /*///////////////////////////////////////////////////////////////
                            CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IPactoSponsorPaymaster
  uint8 public constant PAYMASTER_DATA_VERSION = 1;

  /// @notice Pool balance headroom required vs `maxCost` (115%).
  uint256 internal constant _BALANCE_HEADROOM_BPS = 11_500;

  /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
  //////////////////////////////////////////////////////////////*/

  /// @notice Factory used to anti-spoof squad clone addresses.
  ISquadSponsorFactory internal immutable _FACTORY;

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Factory address is zero.
  error PactoSponsorPaymaster_ZeroFactory();
  /**
   * @notice Unsupported paymaster payload version.
   * @param version Unsupported version byte from `paymasterAndData`.
   */
  error PactoSponsorPaymaster_InvalidVersion(uint8 version);
  /**
   * @notice Clone addresses do not match factory registry.
   * @param squadId Squad identifier with mismatched clone addresses.
   */
  error PactoSponsorPaymaster_CloneMismatch(bytes32 squadId);
  /**
   * @notice EOA senders must use themselves as the eligibility member.
   * @param sender `userOp.sender` for the UserOperation.
   * @param member Member address supplied in `paymasterAndData`.
   */
  error PactoSponsorPaymaster_InvalidMemberBinding(address sender, address member);

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Wires EntryPoint and squad factory references.
   * @param entryPoint ERC-4337 EntryPoint v0.7 for this chain.
   * @param factory_ Squad sponsor factory singleton.
   */
  constructor(IEntryPoint entryPoint, ISquadSponsorFactory factory_) BasePaymaster(entryPoint) {
    if (address(factory_) == address(0)) revert PactoSponsorPaymaster_ZeroFactory();
    _FACTORY = factory_;
  }

  /// @notice Accepts ETH refunded from squad clones after `spendGas`.
  receive() external payable {}

  /*///////////////////////////////////////////////////////////////
                            VALIDATION
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc BasePaymaster
  function _postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256) internal override {
    if (mode != PostOpMode.opSucceeded) return;

    address _sponsor = abi.decode(context, (address));
    ISquadSponsorBase(_sponsor).spendGas(actualGasCost);
  }

  /// @inheritdoc BasePaymaster
  function _validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32,
    uint256 maxCost
  ) internal view override returns (bytes memory context, uint256 validationData) {
    PaymasterData memory _data = _parsePaymasterData(userOp.paymasterAndData);
    _validateRegistry(_data);

    uint256 _requiredBalance = (maxCost * _BALANCE_HEADROOM_BPS) / 10_000;
    if (_data.sponsor.balance < _requiredBalance) {
      return ('', SIG_VALIDATION_FAILED);
    }

    if (!_isEligible(userOp.getSender(), _data)) {
      return ('', SIG_VALIDATION_FAILED);
    }

    context = abi.encode(_data.sponsor);
    validationData = 0;
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Ensures the sponsor clone matches the factory registry for `squadId`.
   * @param data Parsed paymaster payload.
   */
  function _validateRegistry(PaymasterData memory data) internal view {
    ISquadSponsorFactory.SquadRecord memory _record = _FACTORY.squads(data.squadId);
    if (_record.sponsor != data.sponsor) {
      revert PactoSponsorPaymaster_CloneMismatch(data.squadId);
    }
  }

  /**
   * @notice Resolves eligibility and validates the member account binding.
   * @param sender `userOp.sender` (EOA or smart account such as a 4337 Safe).
   * @param data Parsed paymaster payload.
   * @return eligible True when the member may be sponsored.
   */
  function _isEligible(address sender, PaymasterData memory data) internal view returns (bool eligible) {
    if (data.member == address(0)) return false;

    if (sender.code.length == 0) {
      if (sender != data.member) revert PactoSponsorPaymaster_InvalidMemberBinding(sender, data.member);
    }

    eligible = ISquadSponsorBase(data.sponsor).isEligible(data.member);
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
    if (_version != PAYMASTER_DATA_VERSION) revert PactoSponsorPaymaster_InvalidVersion(_version);
  }
}
