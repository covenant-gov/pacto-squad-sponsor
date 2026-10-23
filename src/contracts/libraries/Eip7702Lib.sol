// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Eip7702Lib
 * @author Pacto
 * @notice EIP-7702 delegation-stub checks for paymaster validation.
 */
library Eip7702Lib {
  /// @notice EIP-7702 designated-code length (`0xef0100` plus the 20-byte implementation).
  uint256 internal constant CODE_LENGTH = 23;
  /// @notice EIP-7702 designated-code magic prefix.
  bytes3 internal constant PREFIX = 0xef0100;

  /**
   * @notice True when `code` is an EIP-7702 delegation stub (`0xef0100 || address`).
   * @param code Account bytecode.
   * @return delegation Whether the code matches the 23-byte designated format.
   */
  function isDelegation(bytes memory code) internal pure returns (bool delegation) {
    // casting to 'bytes3' is safe because the length check runs first and the prefix is the first 3 bytes
    // forge-lint: disable-next-line(unsafe-typecast)
    delegation = code.length == CODE_LENGTH && bytes3(code) == PREFIX;
  }

  /**
   * @notice Extracts the implementation address from an EIP-7702 delegation stub.
   * @param code 23-byte designated code (`0xef0100 || implementation`).
   * @return delegated Delegated contract address.
   */
  function implementation(bytes memory code) internal pure returns (address delegated) {
    // code layout: [0..2]=0xef0100, [3..22]=implementation. Skip length word + 3-byte prefix.
    assembly ('memory-safe') {
      delegated := shr(96, mload(add(code, 35)))
    }
  }

  /**
   * @notice Copies `length` bytes of `account` runtime code via `extcodecopy`.
   * @dev Callers should pass `CODE_LENGTH` only after confirming `account.code.length` matches.
   * @param account Account whose code is copied.
   * @param length Number of bytes to copy from offset 0.
   * @return code Copied bytecode.
   */
  function readCode(address account, uint256 length) internal view returns (bytes memory code) {
    code = new bytes(length);
    assembly ('memory-safe') {
      extcodecopy(account, add(code, 0x20), 0, length)
    }
  }
}
