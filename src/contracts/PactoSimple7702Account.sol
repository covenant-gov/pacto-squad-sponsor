// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/* solhint-disable avoid-low-level-calls */

import {IPactoSimple7702Account} from 'interfaces/IPactoSimple7702Account.sol';

import {BaseAccount} from '@account-abstraction/core/BaseAccount.sol';
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from '@account-abstraction/core/Helpers.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

/**
 * @title PactoSimple7702Account
 * @author Pacto
 * @notice Storage-free EIP-7702 account implementation for EntryPoint v0.7.
 * @dev Set-code target for roster EOAs. Validates bare ECDSA over `userOpHash`
 *      (`ECDSA.recover` == `address(this)`). No EIP-191 personal_sign; no MAv2 packing.
 *      Behavior mirrors eth-infinitism Simple7702Account, pinned to EP v0.7.
 *      Implements IERC721Receiver so `_safeMint` to a delegated EOA does not empty-revert.
 */
contract PactoSimple7702Account is IPactoSimple7702Account, BaseAccount, IERC1271, IERC721Receiver {
  /// @notice Canonical EntryPoint v0.7 (same address on mainnet / Sepolia / Arbitrum).
  IEntryPoint private constant _ENTRY_POINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

  /// @notice Accepts ETH to mimic an EOA.
  receive() external payable {}

  /// @notice Accepts arbitrary calldata (with or without value) to mimic an EOA.
  fallback() external payable {}

  /// @inheritdoc IPactoSimple7702Account
  function execute(address dest, uint256 value, bytes calldata func) external {
    _requireFromEntryPointOrSelf();
    _call(dest, value, func);
  }

  /// @inheritdoc IERC721Receiver
  function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }

  /// @inheritdoc IERC1271
  function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
    return _checkSignature(hash, signature) ? this.isValidSignature.selector : bytes4(0xffffffff);
  }

  /// @inheritdoc IPactoSimple7702Account
  function entryPoint() public pure override(BaseAccount, IPactoSimple7702Account) returns (IEntryPoint) {
    return _ENTRY_POINT;
  }

  /**
   * @notice Low-level call helper used by `execute`.
   * @param target Call destination.
   * @param value ETH forwarded with the call.
   * @param data Calldata for `target`.
   */
  function _call(address target, uint256 value, bytes memory data) internal {
    (bool success, bytes memory result) = target.call{value: value}(data);
    if (!success) {
      assembly ('memory-safe') {
        revert(add(result, 32), mload(result))
      }
    }
  }

  /// @inheritdoc BaseAccount
  function _validateSignature(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash
  ) internal view override returns (uint256 validationData) {
    return _checkSignature(userOpHash, userOp.signature) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
  }

  /**
   * @notice Recovers `signature` over `hash` and checks it matches this account (the delegated EOA).
   * @param hash Digest signed by the EOA (EntryPoint `userOpHash` for UserOps).
   * @param signature Raw 65-byte ECDSA signature.
   * @return isValid True when recovery succeeds and equals `address(this)`.
   */
  function _checkSignature(bytes32 hash, bytes memory signature) internal view returns (bool isValid) {
    (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecover(hash, signature);
    return err == ECDSA.RecoverError.NoError && recovered == address(this);
  }

  /**
   * @notice Restricts `execute` to EntryPoint or a 7702 self-call.
   */
  function _requireFromEntryPointOrSelf() internal view {
    require(msg.sender == address(entryPoint()) || msg.sender == address(this), 'not from self or EntryPoint');
  }
}
