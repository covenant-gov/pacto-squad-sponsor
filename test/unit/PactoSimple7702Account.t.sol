// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSimple7702Account} from 'contracts/PactoSimple7702Account.sol';

import {IAccount} from '@account-abstraction/interfaces/IAccount.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from '@account-abstraction/core/Helpers.sol';

import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {Test} from 'forge-std/Test.sol';

/**
 * @title UnitPactoSimple7702Account
 * @author Pacto
 * @notice Unit tests for the storage-free EIP-7702 account (EP v0.7, bare ECDSA).
 */
contract UnitPactoSimple7702Account is Test {
  IEntryPoint internal constant _ENTRY_POINT = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

  PactoSimple7702Account internal _impl;
  uint256 internal _ownerKey;
  address internal _owner;

  function setUp() public {
    _ownerKey = uint256(keccak256('pacto.7702.owner'));
    _owner = vm.addr(_ownerKey);
    _impl = new PactoSimple7702Account();
    // Simulate EIP-7702 set-code: EOA runs the account bytecode.
    vm.etch(_owner, address(_impl).code);
  }

  function test_Unit_7702Account_EntryPointIsV07() external view {
    assertEq(address(PactoSimple7702Account(payable(_owner)).entryPoint()), address(_ENTRY_POINT));
  }

  function test_Unit_7702Account_ValidateUserOp_AcceptsBareEcdsa() external {
    bytes32 _userOpHash = keccak256('userOpHash');
    PackedUserOperation memory _userOp;
    _userOp.signature = _sign(_userOpHash, _ownerKey);

    vm.prank(address(_ENTRY_POINT));
    uint256 _validationData = IAccount(_owner).validateUserOp(_userOp, _userOpHash, 0);

    assertEq(_validationData, SIG_VALIDATION_SUCCESS);
  }

  function test_Unit_7702Account_ValidateUserOp_RejectsWrongSigner() external {
    bytes32 _userOpHash = keccak256('userOpHash');
    uint256 _wrongKey = uint256(keccak256('wrong'));
    PackedUserOperation memory _userOp;
    _userOp.signature = _sign(_userOpHash, _wrongKey);

    vm.prank(address(_ENTRY_POINT));
    uint256 _validationData = IAccount(_owner).validateUserOp(_userOp, _userOpHash, 0);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_7702Account_ValidateUserOp_RejectsWrongHash() external {
    bytes32 _userOpHash = keccak256('userOpHash');
    PackedUserOperation memory _userOp;
    _userOp.signature = _sign(keccak256('otherHash'), _ownerKey);

    vm.prank(address(_ENTRY_POINT));
    uint256 _validationData = IAccount(_owner).validateUserOp(_userOp, _userOpHash, 0);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_Unit_7702Account_ValidateUserOp_RejectsNonEntryPoint() external {
    bytes32 _userOpHash = keccak256('userOpHash');
    PackedUserOperation memory _userOp;
    _userOp.signature = _sign(_userOpHash, _ownerKey);

    vm.expectRevert('account: not from EntryPoint');
    IAccount(_owner).validateUserOp(_userOp, _userOpHash, 0);
  }

  function test_Unit_7702Account_Execute_FromEntryPoint() external {
    address _target = makeAddr('target');
    vm.deal(_owner, 1 ether);

    vm.prank(address(_ENTRY_POINT));
    PactoSimple7702Account(payable(_owner)).execute(_target, 0.1 ether, '');

    assertEq(_target.balance, 0.1 ether);
  }

  function test_Unit_7702Account_Execute_FromSelf() external {
    address _target = makeAddr('target');
    vm.deal(_owner, 1 ether);

    vm.prank(_owner);
    PactoSimple7702Account(payable(_owner)).execute(_target, 0.05 ether, '');

    assertEq(_target.balance, 0.05 ether);
  }

  function test_Unit_7702Account_Execute_RevertsForStranger() external {
    address _stranger = makeAddr('stranger');

    vm.prank(_stranger);
    vm.expectRevert('not from self or EntryPoint');
    PactoSimple7702Account(payable(_owner)).execute(makeAddr('target'), 0, '');
  }

  function test_Unit_7702Account_OnERC721Received_ReturnsSelector() external {
    bytes4 _magic = PactoSimple7702Account(payable(_owner)).onERC721Received(address(0), address(0), 1, '');
    assertEq(_magic, IERC721Receiver.onERC721Received.selector);
  }

  function test_Unit_7702Account_IsValidSignature_AcceptsOwner() external view {
    bytes32 _hash = keccak256('eip1271');
    bytes memory _sig = _sign(_hash, _ownerKey);

    bytes4 _magic = IERC1271(_owner).isValidSignature(_hash, _sig);
    assertEq(_magic, IERC1271.isValidSignature.selector);
  }

  function test_Unit_7702Account_IsValidSignature_RejectsWrongSigner() external view {
    bytes32 _hash = keccak256('eip1271');
    bytes memory _sig = _sign(_hash, uint256(keccak256('wrong')));

    bytes4 _magic = IERC1271(_owner).isValidSignature(_hash, _sig);
    assertEq(_magic, bytes4(0xffffffff));
  }

  function _sign(bytes32 hash, uint256 key) internal pure returns (bytes memory signature) {
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
    signature = abi.encodePacked(r, s, v);
  }
}
