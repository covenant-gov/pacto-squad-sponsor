// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Eip7702Lib} from 'contracts/libraries/Eip7702Lib.sol';
import {PaymasterHeadroomLib} from 'contracts/libraries/PaymasterHeadroomLib.sol';
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
 *      EIP-7702 senders must bind `sender == member` and delegate to `ALLOWED_7702_IMPLEMENTATION`.
 */
contract PactoSponsorPaymaster is IPactoSponsorPaymaster, BasePaymaster {
  using UserOperationLib for PackedUserOperation;

  /// @inheritdoc IPactoSponsorPaymaster
  uint8 public constant PAYMASTER_DATA_VERSION = 1;

  /// @inheritdoc IPactoSponsorPaymaster
  address public immutable ALLOWED_7702_IMPLEMENTATION;
  /// @notice Factory used to anti-spoof squad clone addresses.
  ISquadSponsorFactory internal immutable _FACTORY;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Wires EntryPoint, squad factory, and the EIP-7702 allowlist.
   * @param entryPoint ERC-4337 EntryPoint v0.7 for this chain.
   * @param factory_ Squad sponsor factory singleton.
   * @param allowed7702 EIP-7702 account implementation. `address(0)` rejects all delegated senders.
   */
  constructor(IEntryPoint entryPoint, ISquadSponsorFactory factory_, address allowed7702) BasePaymaster(entryPoint) {
    if (address(factory_) == address(0)) revert SS_ZeroAddress();
    _FACTORY = factory_;
    ALLOWED_7702_IMPLEMENTATION = allowed7702;
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
    (address _defacto, address _wargame) = ISquadSponsorPool(_pool).spendSlots();
    if (_defacto != _data.sponsor && _wargame != _data.sponsor) {
      revert SS_SponsorNotInPoolSlot(_data.sponsor);
    }

    if (ISquadSponsorPool(_pool).spendablePoolWei() < PaymasterHeadroomLib.requiredWei(maxCost)) {
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
    if (_FACTORY.sponsorOf(data.squadId) != data.sponsor) {
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
    } else if (Eip7702Lib.isDelegation(_code)) {
      if (sender != data.member) revert SS_InvalidMemberBinding(sender, data.member);
      address _impl = Eip7702Lib.implementation(_code);
      if (_impl != ALLOWED_7702_IMPLEMENTATION) revert SS_Invalid7702Implementation(_impl);
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
    if (_version != PAYMASTER_DATA_VERSION) revert SS_InvalidVersion(_version);
  }
}
