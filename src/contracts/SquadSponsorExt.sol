// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';
import {HatWireAuth} from 'contracts/utils/HatWireAuth.sol';

import {ISquadSponsor} from 'interfaces/ISquadSponsor.sol';
import {ISquadSponsorExt} from 'interfaces/ISquadSponsorExt.sol';

/**
 * @title SquadSponsorExt
 * @author Pacto
 * @notice Per-squad address-based gas eligibility until hat wiring via `postInitialize`.
 * @dev Deploy behind an EIP-1167 minimal proxy; HATS is baked in via `SquadSponsorConstants.HATS_ADDRESS`.
 */
contract SquadSponsorExt is ISquadSponsorExt, SquadSponsor {
  /// @inheritdoc ISquadSponsorExt
  address public addressOwner;
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
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  function initialize(
    bytes32 _squadId,
    address _paymaster,
    address _factory,
    address _addressOwner
  ) external initializer {
    if (_addressOwner == address(0)) revert SS_ZeroAddress();
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
  ) external override(ISquadSponsor, SquadSponsor) {
    revert SS_UseAddressInitializer();
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  function postInitialize(uint256 _topHatId, address _registry, uint256[] calldata _customHats) external {
    HatWireAuth.requireHatWireAuth(_HATS, factory, addressOwner, msg.sender, _topHatId);
    _wireHats(_topHatId, _registry, _customHats);
    addressOwner = address(0);
  }

  /// @inheritdoc ISquadSponsorExt
  function setPermittedAddress(address member, bool permitted) external onlyAddressOwner {
    if (topHatId != 0) revert SS_AlreadyWired();
    if (member == address(0)) revert SS_ZeroAddress();
    permittedAddress[member] = permitted;
    emit PermittedAddressUpdated(member, permitted);
  }

  /// @inheritdoc ISquadSponsorExt
  function transferAddressOwner(address newOwner) external onlyAddressOwner {
    if (topHatId != 0) revert SS_AlreadyWired();
    if (newOwner == address(0)) revert SS_ZeroAddress();
    address _previousOwner = addressOwner;
    addressOwner = newOwner;
    emit OwnerTransferred(_previousOwner, newOwner);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorExt
  function hatsWired() external view returns (bool wired) {
    wired = topHatId != 0;
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Reverts unless caller is the address owner.
   */
  function _onlyAddressOwner() internal view {
    if (msg.sender != addressOwner) revert SS_NotAuthorized();
  }

  /// @inheritdoc SquadSponsor
  function _isEligible(address member) internal view override returns (bool eligible) {
    if (topHatId == 0) return permittedAddress[member];
    return super._isEligible(member);
  }
}
