// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Eip7702Lib} from 'contracts/libraries/Eip7702Lib.sol';

import {Test} from 'forge-std/Test.sol';

/**
 * @title Eip7702LibHarness
 * @notice Exposes library helpers for direct unit coverage.
 */
contract Eip7702LibHarness {
  function isDelegation(bytes memory code) external pure returns (bool) {
    return Eip7702Lib.isDelegation(code);
  }

  function implementation(bytes memory code) external pure returns (address) {
    return Eip7702Lib.implementation(code);
  }

  function readCode(address account, uint256 length) external view returns (bytes memory) {
    return Eip7702Lib.readCode(account, length);
  }
}

/**
 * @title UnitEip7702Lib
 * @author Pacto
 * @notice Unit tests for EIP-7702 delegation stub parsing.
 */
contract UnitEip7702Lib is Test {
  Eip7702LibHarness internal _lib;

  function setUp() public {
    _lib = new Eip7702LibHarness();
  }

  function test_Unit_Eip7702_ValidDelegation() external {
    address _impl = makeAddr('impl');
    bytes memory _code = abi.encodePacked(bytes3(0xef0100), _impl);

    assertTrue(_lib.isDelegation(_code));
    assertEq(_lib.implementation(_code), _impl);
  }

  function test_Unit_Eip7702_WrongLengthIsNotDelegation() external view {
    assertFalse(_lib.isDelegation(hex'ef0100'));
    assertFalse(_lib.isDelegation(abi.encodePacked(bytes3(0xef0100), bytes21(0))));
  }

  function test_Unit_Eip7702_WrongPrefixIsNotDelegation() external {
    address _impl = makeAddr('impl');
    bytes memory _code = abi.encodePacked(bytes3(0xef0101), _impl);

    assertFalse(_lib.isDelegation(_code));
  }

  function test_Unit_Eip7702_EmptyCodeIsNotDelegation() external view {
    assertFalse(_lib.isDelegation(''));
  }

  function test_Unit_Eip7702_ReadCodeCopiesExactBytes() external {
    address _account = makeAddr('codeAccount');
    address _impl = makeAddr('impl');
    bytes memory _code = abi.encodePacked(bytes3(0xef0100), _impl);
    vm.etch(_account, _code);

    assertEq(_lib.readCode(_account, Eip7702Lib.CODE_LENGTH), _code);
  }
}
