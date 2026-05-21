// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';

import {ISquadSponsor} from 'interfaces/ISquadSponsor.sol';
import {ISquadSponsorExt} from 'interfaces/ISquadSponsorExt.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title SquadSponsorExt
 * @author Pacto
 * @notice Per-squad address-based gas eligibility until hat wiring via `postInitialize`.
 * @dev Deploy behind an EIP-1167 minimal proxy; `_HATS` is immutable on the master copy.
 *
 * Inheritance: `SquadSponsorExt is ISquadSponsorExt, SquadSponsor is SquadSponsorBase`.
 *
 * **Storage layout (append-only — do not reorder or insert variables):**
 * | Slot | Variable              | Contract           |
 * |------|-----------------------|--------------------|
 * | 0–4  | base pool fields      | `SquadSponsorBase` |
 * | 5–7  | hat fields            | `SquadSponsor`     |
 * | 8    | `addressOwner`        | `SquadSponsorExt`  |
 * | 8*   | `hatsWired` (packed)  | `SquadSponsorExt`  |
 * | 9    | `permittedAddress`    | `SquadSponsorExt`  |
 */
contract SquadSponsorExt is ISquadSponsorExt, SquadSponsor {
  /*///////////////////////////////////////////////////////////////
                       STORAGE — SLOT 8–9
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  address public addressOwner;
  /// @inheritdoc ISquadSponsorExt
  bool public hatsWired;
  /// @inheritdoc ISquadSponsorExt
  mapping(address member => bool permitted) public permittedAddress;

  /*///////////////////////////////////////////////////////////////
                            MODIFIERS
  //////////////////////////////////////////////////////////////*/

  /// @notice Restricts to the early-bird address owner.
  modifier onlyAddressOwner() {
    _onlyAddressOwner();
    _;
  }

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Master-copy constructor; bakes the Hats singleton into implementation runtime code.
   * @param hats_ Hats Protocol address for this chain.
   */
  constructor(IHats hats_) SquadSponsor(hats_) {}

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  function initialize(
    bytes32 _squadId,
    address _paymaster,
    address _factory,
    address _addressOwner
  ) external initializer {
    if (_addressOwner == address(0)) revert SquadSponsorExt_ZeroAddress();
    _sponsorBaseInit(_squadId, _paymaster, _factory);
    addressOwner = _addressOwner;
  }

  /// @inheritdoc ISquadSponsor
  function initialize(
    bytes32,
    address,
    address,
    uint256,
    address,
    uint256[] calldata
  ) external pure override(ISquadSponsor, SquadSponsor) {
    revert SquadSponsorExt_UseAddressInitializer();
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  function setPermittedAddress(address member, bool permitted) external onlyAddressOwner {
    if (hatsWired) revert SquadSponsor_HatsAlreadyWired();
    if (member == address(0)) revert SquadSponsorExt_ZeroAddress();
    permittedAddress[member] = permitted;
    emit PermittedAddressUpdated(member, permitted);
  }

  /// @inheritdoc ISquadSponsor
  function postInitialize(
    uint256 _topHatId,
    address _registry,
    uint256[] calldata _customHats
  ) external override(ISquadSponsor, SquadSponsor) {
    if (hatsWired) revert SquadSponsor_HatsAlreadyWired();
    _requireWireAuth(_topHatId);
    _sponsorHatInit(_topHatId, _registry, _customHats);
    hatsWired = true;
    addressOwner = address(0);
    ISquadSponsorFactory(factory).registerHatsWiring(squadId, _topHatId);
    emit HatsSponsorshipWired(squadId, _topHatId);
  }

  /// @inheritdoc ISquadSponsorExt
  function transferAddressOwner(address newOwner) external onlyAddressOwner {
    if (hatsWired) revert SquadSponsor_HatsAlreadyWired();
    if (newOwner == address(0)) revert SquadSponsorExt_ZeroAddress();
    address _previousOwner = addressOwner;
    addressOwner = newOwner;
    emit AddressOwnerTransferred(_previousOwner, newOwner);
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Reverts unless caller is factory, address owner, or Hats tree admin.
   * @param _topHatId Top hat id being wired.
   */
  function _requireWireAuth(uint256 _topHatId) internal view {
    if (msg.sender == factory) return;
    if (msg.sender == addressOwner) return;
    if (_HATS.isAdminOfHat(msg.sender, _topHatId)) return;
    revert SquadSponsor_NotAllowed();
  }

  /**
   * @notice Reverts unless caller is the address owner.
   */
  function _onlyAddressOwner() internal view {
    if (msg.sender != addressOwner) revert SquadSponsorExt_NotAddressOwner();
  }

  /// @inheritdoc SquadSponsor
  function _isEligible(address member) internal view override returns (bool eligible) {
    if (!hatsWired) return permittedAddress[member];
    return super._isEligible(member);
  }
}
