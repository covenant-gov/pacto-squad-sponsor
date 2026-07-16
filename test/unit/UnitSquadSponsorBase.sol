// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsorFactory} from 'contracts/SquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';
import {Test} from 'forge-std/Test.sol';

/**
 * @title UnitSquadSponsorBase
 * @author Pacto
 * @notice Shared fixture for squad sponsor unit tests.
 */
abstract contract UnitSquadSponsorBase is Test {
  /// @dev Hats Protocol v1 singleton — must match `SquadSponsorBase._HATS`.
  address internal constant _HATS = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
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

    _factory = new SquadSponsorFactory(IEntryPoint(_ENTRY_POINT));
    _paymaster = PactoSponsorPaymaster(payable(_factory.PAYMASTER()));
  }

  function _createSquadExt(bytes32 squadId) internal returns (address sponsor) {
    sponsor = _factory.createSquadSponsorExt(squadId, address(this));
  }

  function _createSquadExtWithDeposit(bytes32 squadId, uint256 depositAmount) internal returns (address sponsor) {
    sponsor = _factory.createSquadSponsorExt{value: depositAmount}(squadId, address(this));
  }

  function _createSquadHat(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] memory customEligibleHats
  ) internal returns (address sponsor) {
    sponsor = _factory.createSquadSponsor(squadId, topHatId, registry, customEligibleHats);
  }

  function _mockHatsAdmin(address user, uint256 topHatId, bool isAdmin) internal {
    vm.mockCall(_HATS, abi.encodeWithSignature('isAdminOfHat(address,uint256)', user, topHatId), abi.encode(isAdmin));
  }

  function _mockHatWearer(address wearer, uint256 hatId, bool isWearer) internal {
    vm.mockCall(_HATS, abi.encodeWithSignature('isWearerOfHat(address,uint256)', wearer, hatId), abi.encode(isWearer));
  }
}
