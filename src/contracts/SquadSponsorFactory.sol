// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorVault} from 'contracts/SquadSponsorVault.sol';

import {ISquadSponsorExt} from 'interfaces/ISquadSponsorExt.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title SquadSponsorFactory
 * @author Pacto
 * @notice Chain singleton that deploys per-squad vault, Ext, and hat clones.
 */
contract SquadSponsorFactory is ISquadSponsorFactory {
  /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  address public immutable paymaster;
  /// @inheritdoc ISquadSponsorFactory
  address public immutable hats;

  /*///////////////////////////////////////////////////////////////
                            STORAGE
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  address public vaultImplementation;
  /// @inheritdoc ISquadSponsorFactory
  address public extImplementation;
  /// @inheritdoc ISquadSponsorFactory
  address public sponsorImplementation;
  /// @notice Per-squad registry rows keyed by squad id.
  mapping(bytes32 squadId => SquadRecord record) internal _squads;
  /// @inheritdoc ISquadSponsorFactory
  mapping(address vault => bytes32 squadId) public squadIdByVault;
  /// @inheritdoc ISquadSponsorFactory
  mapping(address ext => bytes32 squadId) public squadIdByExt;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploys master copies for vault, Ext, and hat clones.
   * @param paymaster_ ERC-4337 paymaster authorized to spend from vault clones.
   * @param hats_ Hats Protocol singleton for Ext and hat clones.
   */
  constructor(address paymaster_, address hats_) {
    if (paymaster_ == address(0)) revert SquadSponsorFactory_ZeroAddress('paymaster');
    if (hats_ == address(0)) revert SquadSponsorFactory_ZeroAddress('hats');

    paymaster = paymaster_;
    hats = hats_;

    vaultImplementation = address(new SquadSponsorVault());
    extImplementation = address(new SquadSponsorExt(IHats(hats_)));
    sponsorImplementation = address(new SquadSponsor(IHats(hats_)));
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  function createSquad(bytes32 squadId) external payable returns (address vault, address ext) {
    if (_squads[squadId].vault != address(0)) revert SquadSponsorFactory_SquadAlreadyExists(squadId);

    vault = Clones.clone(vaultImplementation);
    ext = Clones.clone(extImplementation);

    SquadSponsorVault(payable(vault)).initialize(squadId, ext, paymaster, address(this));
    SquadSponsorExt(ext).initialize(squadId, vault, address(this), msg.sender);

    _squads[squadId] = SquadRecord({vault: vault, ext: ext, base: address(0), topHatId: 0});
    squadIdByVault[vault] = squadId;
    squadIdByExt[ext] = squadId;

    emit SquadCreated(squadId, vault, ext, msg.sender);

    if (msg.value > 0) {
      SquadSponsorVault(payable(vault)).depositFor{value: msg.value}(msg.sender);
    }
  }

  /// @inheritdoc ISquadSponsorFactory
  function cloneAndWireSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external returns (address base) {
    SquadRecord storage _record = _squads[squadId];
    if (_record.ext == address(0)) revert SquadSponsorFactory_UnknownSquad(squadId);

    base = Clones.clone(sponsorImplementation);
    SquadSponsor(base).initialize(squadId, topHatId, registry, customEligibleHats);

    ISquadSponsorExt(_record.ext).postInitialize(topHatId, base);
  }

  /// @inheritdoc ISquadSponsorFactory
  function registerHatsWiring(bytes32 squadId, uint256 topHatId, address base) external {
    SquadRecord storage _record = _squads[squadId];
    if (_record.ext == address(0)) revert SquadSponsorFactory_UnknownSquad(squadId);
    if (msg.sender != _record.ext) revert SquadSponsorFactory_NotExt();

    _record.base = base;
    _record.topHatId = topHatId;

    emit HatsWiringRegistered(squadId, topHatId, base);
  }

  /// @inheritdoc ISquadSponsorFactory
  function squads(bytes32 squadId) external view returns (SquadRecord memory record) {
    record = _squads[squadId];
  }
}
