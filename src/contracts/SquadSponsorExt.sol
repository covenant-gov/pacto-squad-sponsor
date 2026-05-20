// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorEligibility} from 'interfaces/ISquadSponsorEligibility.sol';
import {ISquadSponsorExt} from 'interfaces/ISquadSponsorExt.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';
import {ISquadSponsorVault} from 'interfaces/ISquadSponsorVault.sol';

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title SquadSponsorExt
 * @author Pacto
 * @notice Per-squad address-based gas eligibility until hat wiring via `postInitialize`.
 * @dev Deploy behind an EIP-1167 minimal proxy; `_HATS` is immutable on the master copy.
 */
contract SquadSponsorExt is ISquadSponsorExt, Initializable {
  /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
  //////////////////////////////////////////////////////////////*/

  /// @notice Hats Protocol singleton for tree-owner gate checks.
  IHats internal immutable _HATS;

  /*///////////////////////////////////////////////////////////////
                            STORAGE
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  bytes32 public squadId;
  /// @inheritdoc ISquadSponsorExt
  address public vault;
  /// @inheritdoc ISquadSponsorExt
  address public factory;
  /// @inheritdoc ISquadSponsorExt
  address public addressOwner;
  /// @inheritdoc ISquadSponsorExt
  bool public hatsWired;
  /// @inheritdoc ISquadSponsorExt
  address public squadSponsorBase;
  /// @inheritdoc ISquadSponsorExt
  mapping(address member => bool permitted) public permittedAddress;

  /*///////////////////////////////////////////////////////////////
                            MODIFIERS
  //////////////////////////////////////////////////////////////*/

  /// @notice Restricts to the early-bird address owner.
  modifier onlyAddressOwner() {
    if (msg.sender != addressOwner) revert SquadSponsorExt_NotAddressOwner();
    _;
  }

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Master-copy constructor; bakes the Hats singleton into implementation runtime code.
   * @param hats_ Hats Protocol address for this chain.
   */
  constructor(IHats hats_) {
    _HATS = hats_;
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  function initialize(bytes32 _squadId, address _vault, address _factory, address _addressOwner) external initializer {
    if (_vault == address(0) || _factory == address(0) || _addressOwner == address(0)) {
      revert SquadSponsorExt_ZeroAddress();
    }
    squadId = _squadId;
    vault = _vault;
    factory = _factory;
    addressOwner = _addressOwner;
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  function setPermittedAddress(address member, bool permitted) external onlyAddressOwner {
    if (member == address(0)) revert SquadSponsorExt_ZeroAddress();
    permittedAddress[member] = permitted;
    emit PermittedAddressUpdated(member, permitted);
  }

  /// @inheritdoc ISquadSponsorExt
  function postInitialize(uint256 topHatId, address squadSponsorBase_) external {
    if (hatsWired) revert SquadSponsorExt_HatsAlreadyWired();
    if (squadSponsorBase_ == address(0)) revert SquadSponsorExt_ZeroBase();
    _requireWireAuth(topHatId);

    hatsWired = true;
    squadSponsorBase = squadSponsorBase_;

    ISquadSponsorVault(vault).linkTopHat(topHatId);
    ISquadSponsorFactory(factory).registerHatsWiring(squadId, topHatId, squadSponsorBase_);

    emit HatsSponsorshipWired(squadId, topHatId, squadSponsorBase_);
  }

  /// @inheritdoc ISquadSponsorExt
  function transferAddressOwner(address newOwner) external onlyAddressOwner {
    if (newOwner == address(0)) revert SquadSponsorExt_ZeroAddress();
    address _previousOwner = addressOwner;
    addressOwner = newOwner;
    emit AddressOwnerTransferred(_previousOwner, newOwner);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorEligibility
  function isEligible(address member) external view returns (bool eligible) {
    eligible = permittedAddress[member];
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Reverts unless caller is factory, address owner, or Hats tree admin.
   * @param topHatId Top hat id being wired.
   */
  function _requireWireAuth(uint256 topHatId) internal view {
    if (msg.sender == factory) return;
    if (msg.sender == addressOwner) return;
    if (_HATS.isAdminOfHat(msg.sender, topHatId)) return;
    revert SquadSponsorExt_NotAllowed();
  }
}
