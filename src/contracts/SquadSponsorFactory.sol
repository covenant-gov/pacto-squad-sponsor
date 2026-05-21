// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsor} from 'contracts/SquadSponsor.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title SquadSponsorFactory
 * @author Pacto
 * @notice Chain singleton that deploys per-squad sponsor clones.
 */
contract SquadSponsorFactory is ISquadSponsorFactory {
  /*///////////////////////////////////////////////////////////////
                            IMMUTABLES
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  address public immutable PAYMASTER;
  /// @inheritdoc ISquadSponsorFactory
  address public immutable HATS;

  /*///////////////////////////////////////////////////////////////
                            STORAGE
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  address public sponsorImplementation;
  /// @inheritdoc ISquadSponsorFactory
  address public extImplementation;
  /// @notice Per-squad registry rows keyed by squad id.
  mapping(bytes32 squadId => SquadRecord record) internal _squads;
  /// @inheritdoc ISquadSponsorFactory
  mapping(address sponsor => bytes32 squadId) public squadIdBySponsor;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploys master copies for SquadSponsor and SquadSponsorExt clones.
   * @param paymaster_ ERC-4337 paymaster authorized to spend from sponsor clones.
   * @param hats_ Hats Protocol singleton for sponsor clones.
   */
  constructor(address paymaster_, address hats_) {
    if (paymaster_ == address(0)) revert SquadSponsorFactory_ZeroAddress('paymaster');
    if (hats_ == address(0)) revert SquadSponsorFactory_ZeroAddress('hats');

    PAYMASTER = paymaster_;
    HATS = hats_;

    sponsorImplementation = address(new SquadSponsor(IHats(hats_)));
    extImplementation = address(new SquadSponsorExt(IHats(hats_)));
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsorExt(bytes32 squadId) external payable returns (address sponsor) {
    if (_squads[squadId].sponsor != address(0)) revert SquadSponsorFactory_SquadAlreadyExists(squadId);

    sponsor = Clones.clone(extImplementation);
    SquadSponsorExt(payable(sponsor)).initialize(squadId, PAYMASTER, address(this), msg.sender);

    _squads[squadId] = SquadRecord({sponsor: sponsor, variant: SquadVariant.EXT, topHatId: 0});
    squadIdBySponsor[sponsor] = squadId;

    emit SquadCreated(squadId, sponsor, SquadVariant.EXT, msg.sender);

    if (msg.value > 0) {
      SquadSponsorExt(payable(sponsor)).depositFor{value: msg.value}(msg.sender);
    }
  }

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external payable returns (address sponsor) {
    if (_squads[squadId].sponsor != address(0)) {
      revert SquadSponsorFactory_SquadAlreadyExists(squadId);
    }

    sponsor = Clones.clone(sponsorImplementation);
    SquadSponsor(payable(sponsor)).initialize(squadId, PAYMASTER, address(this), topHatId, registry, customEligibleHats);

    _squads[squadId] = SquadRecord({sponsor: sponsor, variant: SquadVariant.SPONSOR, topHatId: topHatId});
    squadIdBySponsor[sponsor] = squadId;

    emit SquadCreated(squadId, sponsor, SquadVariant.SPONSOR, msg.sender);

    if (msg.value > 0) {
      SquadSponsor(payable(sponsor)).depositFor{value: msg.value}(msg.sender);
    }
  }

  /// @inheritdoc ISquadSponsorFactory
  function registerHatsWiring(bytes32 squadId, uint256 topHatId) external {
    SquadRecord storage _record = _squads[squadId];
    if (_record.sponsor == address(0)) revert SquadSponsorFactory_UnknownSquad(squadId);
    if (msg.sender != _record.sponsor) revert SquadSponsorFactory_NotSponsor();

    _record.topHatId = topHatId;

    emit HatsWiringRegistered(squadId, topHatId);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  function squads(bytes32 squadId) external view returns (SquadRecord memory record) {
    record = _squads[squadId];
  }
}
