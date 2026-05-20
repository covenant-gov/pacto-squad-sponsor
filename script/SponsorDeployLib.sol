// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

/// @notice CREATE2 helpers for factory ↔ paymaster circular constructor deps.
library SponsorDeployLib {
  error SponsorDeployLib_Unresolved();

  bytes32 internal constant _SALT_TAG = keccak256('pacto.squad.sponsor/deploy/v1');

  struct Addresses {
    bytes32 saltFactory;
    bytes32 saltPaymaster;
    address factory;
    address paymaster;
  }

  /// @notice Derive paymaster salt from factory salt.
  function paymasterSalt(bytes32 saltFactory) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(_SALT_TAG, saltFactory));
  }

  /// @notice Init code hash for factory CREATE2 deploy.
  function factoryInitCodeHash(address paymaster, address hats) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(type(SquadSponsorFactory).creationCode, abi.encode(paymaster, hats)));
  }

  /// @notice Init code hash for paymaster CREATE2 deploy.
  function paymasterInitCodeHash(address entryPoint, address factory) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(type(PactoSponsorPaymaster).creationCode, abi.encode(entryPoint, factory)));
  }

  /**
   * @notice Fixed-point CREATE2 address prediction for a known factory salt.
   * @dev Set `SPONSOR_FACTORY_SALT` when the default salt does not converge.
   */
  function predict(
    address deployer,
    bytes32 saltFactory,
    address entryPoint,
    address hats
  ) internal pure returns (Addresses memory addrs) {
    addrs.saltFactory = saltFactory;
    addrs.saltPaymaster = paymasterSalt(saltFactory);

    address factory = address(0x1);
    for (uint256 j = 0; j < 32; j++) {
      addrs.paymaster = _create2(deployer, addrs.saltPaymaster, paymasterInitCodeHash(entryPoint, factory));
      address factoryNext = _create2(deployer, addrs.saltFactory, factoryInitCodeHash(addrs.paymaster, hats));
      if (factoryNext == factory && j > 0) {
        address paymasterCheck = _create2(deployer, addrs.saltPaymaster, paymasterInitCodeHash(entryPoint, factoryNext));
        if (paymasterCheck == addrs.paymaster) {
          addrs.factory = factoryNext;
          return addrs;
        }
      }
      factory = factoryNext;
    }
    revert SponsorDeployLib_Unresolved();
  }

  /// @notice Deploy factory and paymaster at the predicted CREATE2 addresses.
  function deploy(
    Addresses memory addrs,
    address entryPoint,
    address hats
  ) internal returns (SquadSponsorFactory factory, PactoSponsorPaymaster paymaster) {
    paymaster = new PactoSponsorPaymaster{
      salt: addrs.saltPaymaster
    }(IEntryPoint(entryPoint), ISquadSponsorFactory(addrs.factory));
    if (address(paymaster) != addrs.paymaster) revert SponsorDeployLib_Unresolved();

    // forge-lint: disable-next-line(unsafe-typecast)
    factory = new SquadSponsorFactory{salt: addrs.saltFactory}(addrs.paymaster, hats);
    if (address(factory) != addrs.factory) revert SponsorDeployLib_Unresolved();
  }

  function _create2(address deployer, bytes32 salt, bytes32 initCodeHash) private pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
  }
}
