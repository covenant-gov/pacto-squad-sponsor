// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';
import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {SIG_VALIDATION_FAILED} from '@account-abstraction/core/Helpers.sol';
import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {PackedUserOperation} from '@account-abstraction/interfaces/PackedUserOperation.sol';

import {IntegrationBase} from 'test/integration/IntegrationBase.sol';
import {MockSmartAccount} from 'test/unit/helpers/TestHelpers.sol';

/**
 * @title E2EPactoSponsorPaymasterTest
 * @author Pacto
 * @notice End-to-end scenarios for `PactoSponsorPaymaster`; inherits `IntegrationBase` (mainnet fork required).
 */
contract E2EPactoSponsorPaymasterTest is IntegrationBase {
  /*///////////////////////////////////////////////////////////////
                        integration wiring
  //////////////////////////////////////////////////////////////*/

  function test_integration_paymasterDataVersion() public view {
    assertEq(_paymaster.PAYMASTER_DATA_VERSION(), 1);
  }

  function test_integration_paymasterWiredToFactory() public view {
    assertEq(_factory.PAYMASTER(), address(_paymaster));
    assertGt(_config.entryPoint.code.length, 0);
  }

  /*///////////////////////////////////////////////////////////////
                        validatePaymasterUserOp
  //////////////////////////////////////////////////////////////*/

  function test_e2e_validatePaymasterUserOp_succeedsForPermittedMember() public withPermittedMember {
    PackedUserOperation memory _userOp = _buildExtUserOp(_member, _member);

    (bytes memory _context, uint256 _validationData) = _validatePaymaster(_userOp, 1 ether);

    assertEq(_validationData, 0);
    assertEq(_context, abi.encode(_extSponsor.pool()));
  }

  function test_e2e_validatePaymasterUserOp_rejectsIneligibleMember() public withDeployedExtSquad {
    PackedUserOperation memory _userOp = _buildExtUserOp(_stranger, _stranger);

    (, uint256 _validationData) = _validatePaymaster(_userOp, 1 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_e2e_validatePaymasterUserOp_rejectsInsufficientPoolBalance() public withPermittedMember {
    PackedUserOperation memory _userOp = _buildExtUserOp(_member, _member);

    (, uint256 _validationData) = _validatePaymaster(_userOp, _E2E_POOL_DEPOSIT);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_e2e_validatePaymasterUserOp_rejectsCloneMismatch() public withPermittedMember {
    address _wrongSponsor = makeAddr('e2eWrongSponsor');
    PackedUserOperation memory _userOp = _buildUserOp(_member, _squadId, _wrongSponsor, _member);

    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_CloneMismatch.selector, _squadId));
    _validatePaymaster(_userOp, 1 ether);
  }

  function test_e2e_validatePaymasterUserOp_rejectsZeroMember() public withDeployedExtSquad {
    PackedUserOperation memory _userOp = _buildExtUserOp(_addressOwner, address(0));

    (, uint256 _validationData) = _validatePaymaster(_userOp, 1 ether);

    assertEq(_validationData, SIG_VALIDATION_FAILED);
  }

  function test_e2e_validatePaymasterUserOp_rejectsEoaMemberBindingMismatch() public withPermittedMember {
    address _other = makeAddr('e2eBindingOther');
    PackedUserOperation memory _userOp = _buildExtUserOp(_member, _other);

    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_InvalidMemberBinding.selector, _member, _other));
    _validatePaymaster(_userOp, 1 ether);
  }

  function test_e2e_validatePaymasterUserOp_rejectsInvalidVersion() public withPermittedMember {
    bytes memory _payload = abi.encode(uint8(99), _squadId, address(_extSponsor), _member);
    bytes memory _header = abi.encodePacked(address(_paymaster), uint128(100_000), uint128(50_000));
    PackedUserOperation memory _userOp;
    _userOp.sender = _member;
    _userOp.paymasterAndData = bytes.concat(_header, _payload);

    vm.expectRevert(abi.encodeWithSelector(ISquadSponsorCommon.SS_InvalidVersion.selector, uint8(99)));
    _validatePaymaster(_userOp, 1 ether);
  }

  function test_e2e_validatePaymasterUserOp_succeedsForSmartAccountSender() public withPermittedMember {
    MockSmartAccount _smartAccount = new MockSmartAccount();
    PackedUserOperation memory _userOp = _buildExtUserOp(address(_smartAccount), _member);

    (, uint256 _validationData) = _validatePaymaster(_userOp, 1 ether);

    assertEq(_validationData, 0);
  }

  function test_e2e_validatePaymasterUserOp_succeedsAfterHatWiring() public withWiredExtSquad {
    address _wearer = makeAddr('e2eWiredHatWearer');
    _mockHatWearer(_wearer, _E2E_CUSTOM_HAT_ID, true);

    PackedUserOperation memory _userOp = _buildExtUserOp(_wearer, _wearer);

    (, uint256 _validationData) = _validatePaymaster(_userOp, 1 ether);

    assertEq(_validationData, 0);
  }

  function test_e2e_validatePaymasterUserOp_succeedsForHatSponsorClone() public withDeployedHatSponsor {
    address _wearer = makeAddr('e2eHatPaymasterWearer');
    _mockHatWearer(_wearer, _E2E_CUSTOM_HAT_ID, true);

    PackedUserOperation memory _userOp = _buildUserOp(_wearer, _hatSquadId, address(_hatSponsor), _wearer);

    (, uint256 _validationData) = _validatePaymaster(_userOp, 0.8 ether);

    assertEq(_validationData, 0);
  }

  function test_e2e_validatePaymasterUserOp_succeedsForWarGameSquadIdWhileParentHatsWired() public withWiredExtSquad {
    vm.deal(_addressOwner, 10 ether);
    vm.prank(_addressOwner);
    (address _gameSponsor,, bytes32 _gameSquadId) =
      _factory.createWarGameSponsorExt{value: _E2E_POOL_DEPOSIT}(_squadId, _addressOwner);
    SquadSponsorExt _gameExt = SquadSponsorExt(payable(_gameSponsor));

    address _gameMember = makeAddr('e2eWarGameMember');
    vm.prank(_addressOwner);
    _gameExt.setPermittedAddress(_gameMember, true);

    PackedUserOperation memory _userOp = _buildUserOp(_gameMember, _gameSquadId, _gameSponsor, _gameMember);
    (, uint256 _validationData) = _validatePaymaster(_userOp, 1 ether);
    assertEq(_validationData, 0);

    PackedUserOperation memory _parentOp = _buildExtUserOp(_gameMember, _gameMember);
    (, uint256 _parentValidation) = _validatePaymaster(_parentOp, 1 ether);
    assertEq(_parentValidation, SIG_VALIDATION_FAILED);
  }

  /*///////////////////////////////////////////////////////////////
                        postOp
  //////////////////////////////////////////////////////////////*/

  function test_e2e_postOp_spendsFromSponsorOnSuccess() public withPermittedMember {
    PackedUserOperation memory _userOp = _buildExtUserOp(_member, _member);
    (bytes memory _context,) = _validatePaymaster(_userOp, 1 ether);

    uint256 _paymasterBefore = address(_paymaster).balance;
    _postOpSucceeded(_context, 1 ether);

    assertEq(address(_pool()).balance, _E2E_POOL_DEPOSIT - 1 ether);
    assertEq(address(_paymaster).balance - _paymasterBefore, 1 ether);
  }

  function test_e2e_postOp_skipsSpendOnRevert() public withPermittedMember {
    PackedUserOperation memory _userOp = _buildExtUserOp(_member, _member);
    (bytes memory _context,) = _validatePaymaster(_userOp, 1 ether);

    _postOpReverted(_context, 1 ether);

    assertEq(address(_pool()).balance, _E2E_POOL_DEPOSIT);
  }

  /*///////////////////////////////////////////////////////////////
                        constructor
  //////////////////////////////////////////////////////////////*/

  function test_e2e_paymasterConstructor_revertsOnZeroFactory() public {
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    new PactoSponsorPaymaster(IEntryPoint(_config.entryPoint), ISquadSponsorFactory(address(0)), _mockRegistry);
  }

  function test_e2e_paymasterConstructor_revertsOnZeroRegistry() public {
    vm.expectRevert(ISquadSponsorCommon.SS_ZeroAddress.selector);
    new PactoSponsorPaymaster(
      IEntryPoint(_config.entryPoint), ISquadSponsorFactory(address(_factory)), IPactoProtocolRegistry(address(0))
    );
  }
}
