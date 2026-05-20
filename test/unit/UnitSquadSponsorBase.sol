// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {Test} from 'forge-std/Test.sol';

/**
 * @title UnitSquadSponsorBase
 * @author Pacto
 * @notice Shared fixture for squad sponsor unit tests.
 */
abstract contract UnitSquadSponsorBase is Test {
  address internal constant _HATS = address(uint160(uint256(keccak256('pacto.sponsor.HATS'))));
  address internal constant _ENTRY_POINT = address(uint160(uint256(keccak256('pacto.sponsor.ENTRY_POINT'))));

  SquadSponsorFactory internal _factory;
  PactoSponsorPaymaster internal _paymaster;

  bytes32 internal _squadId = keccak256('squad-alpha');

  function setUp() public virtual {
    vm.etch(_HATS, hex'00');
    vm.etch(_ENTRY_POINT, hex'00');
    vm.mockCall(_HATS, abi.encodeWithSignature('isAdminOfHat(address,uint256)'), abi.encode(false));
    vm.mockCall(_HATS, abi.encodeWithSignature('isWearerOfHat(address,uint256)'), abi.encode(false));
    vm.mockCall(
      _ENTRY_POINT,
      abi.encodeWithSelector(IERC165.supportsInterface.selector, type(IEntryPoint).interfaceId),
      abi.encode(true)
    );

    uint256 nonce = vm.getNonce(address(this));
    address paymasterAddr = vm.computeCreateAddress(address(this), nonce);
    address factoryAddr = vm.computeCreateAddress(address(this), nonce + 1);

    _paymaster = new PactoSponsorPaymaster(IEntryPoint(_ENTRY_POINT), ISquadSponsorFactory(factoryAddr));
    _factory = new SquadSponsorFactory(paymasterAddr, _HATS);
  }

  function _createSquad(bytes32 squadId, uint256 depositAmount) internal returns (address vault, address ext) {
    if (depositAmount == 0) {
      (vault, ext) = _factory.createSquad(squadId);
    } else {
      (vault, ext) = _factory.createSquad{value: depositAmount}(squadId);
    }
  }

  function _mockHatsAdmin(address user, uint256 topHatId, bool isAdmin) internal {
    vm.mockCall(_HATS, abi.encodeWithSignature('isAdminOfHat(address,uint256)', user, topHatId), abi.encode(isAdmin));
  }

  function _mockHatWearer(address wearer, uint256 hatId, bool isWearer) internal {
    vm.mockCall(_HATS, abi.encodeWithSignature('isWearerOfHat(address,uint256)', wearer, hatId), abi.encode(isWearer));
  }
}
