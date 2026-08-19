// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsor} from 'contracts/SquadSponsor.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorConstants} from 'contracts/utils/constants/SquadSponsorConstants.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

/**
 * @title SquadSponsorFactory
 * @author Pacto
 * @notice Chain singleton that deploys per-squad sponsor clones and its wired paymaster.
 */
contract SquadSponsorFactory is ISquadSponsorFactory {
  /// @inheritdoc ISquadSponsorFactory
  uint256 public constant MIN_PAYMASTER_STAKE_WEI = 0.1 ether;
  /// @inheritdoc ISquadSponsorFactory
  uint32 public constant MIN_UNSTAKE_DELAY_SEC = 1 days;

  /// @inheritdoc ISquadSponsorFactory
  bytes32 public constant WAR_GAME_NS = keccak256('pacto.sponsor.wargame');

  /// @inheritdoc ISquadSponsorFactory
  address public immutable PAYMASTER;

  /// @inheritdoc ISquadSponsorFactory
  address public sponsorImplementation;
  /// @inheritdoc ISquadSponsorFactory
  address public extImplementation;

  /// @inheritdoc ISquadSponsorFactory
  address public paymasterStaker;

  /// @notice Per-squad registry rows keyed by squad id.
  mapping(bytes32 squadId => SquadRecord record) internal _squads;
  /// @inheritdoc ISquadSponsorFactory
  mapping(address sponsor => bytes32 squadId) public squadIdBySponsor;

  /// @inheritdoc ISquadSponsorFactory
  mapping(bytes32 parentSquadId => uint256 count) public warGameRoundCount;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Deploys the chain paymaster and master copies for squad clones.
   * @param entryPoint ERC-4337 EntryPoint v0.7 for this chain.
   * @param allowed7702Implementation Canonical EIP-7702 account implementation allowlisted by the paymaster
   *        (`address(0)` rejects all EIP-7702 delegated senders).
   */
  constructor(IEntryPoint entryPoint, address allowed7702Implementation) {
    if (address(entryPoint) == address(0)) revert SS_ZeroField('entryPoint');
    PAYMASTER =
      address(new PactoSponsorPaymaster(entryPoint, ISquadSponsorFactory(address(this)), allowed7702Implementation));
    sponsorImplementation = address(new SquadSponsor());
    extImplementation = address(new SquadSponsorExt());
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsorExt(bytes32 squadId, address addressOwner) external payable returns (address sponsor) {
    if (_squads[squadId].sponsor != address(0)) revert SS_SquadAlreadyExists(squadId);
    if (addressOwner == address(0)) revert SS_ZeroAddress();

    sponsor = Clones.clone(extImplementation);
    SquadSponsorExt(payable(sponsor)).initialize(squadId, PAYMASTER, address(this), addressOwner);

    _registerSquad(squadId, sponsor, SquadVariant.EXT, 0, addressOwner);
    _depositIfAny(sponsor);
  }

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external payable returns (address sponsor) {
    if (_squads[squadId].sponsor != address(0)) {
      revert SS_SquadAlreadyExists(squadId);
    }

    sponsor = Clones.clone(sponsorImplementation);
    SquadSponsor(payable(sponsor)).initialize(squadId, PAYMASTER, address(this), topHatId, registry, customEligibleHats);

    _registerSquad(squadId, sponsor, SquadVariant.SPONSOR, topHatId, msg.sender);
    _depositIfAny(sponsor);
  }

  /// @inheritdoc ISquadSponsorFactory
  function createWarGameSponsorExt(
    bytes32 parentSquadId,
    address addressOwner
  ) external payable returns (address sponsor, uint256 round, bytes32 gameSquadId) {
    if (parentSquadId == bytes32(0)) revert SS_ZeroField('parentSquadId');
    if (addressOwner == address(0)) revert SS_ZeroAddress();

    round = ++warGameRoundCount[parentSquadId];
    gameSquadId = warGameSquadId(parentSquadId, round);
    if (_squads[gameSquadId].sponsor != address(0)) revert SS_SquadAlreadyExists(gameSquadId);

    sponsor = Clones.cloneDeterministic(extImplementation, gameSquadId);
    SquadSponsorExt(payable(sponsor)).initialize(gameSquadId, PAYMASTER, address(this), addressOwner);

    _registerSquad(gameSquadId, sponsor, SquadVariant.EXT, 0, addressOwner);
    _depositIfAny(sponsor);
    emit WarGameSponsorCreated(parentSquadId, round, gameSquadId, sponsor);
  }

  /// @inheritdoc ISquadSponsorFactory
  function registerHatsWiring(bytes32 squadId, uint256 topHatId) external {
    SquadRecord storage _record = _squads[squadId];
    if (_record.sponsor == address(0)) revert SS_UnknownSquad(squadId);
    if (msg.sender != _record.sponsor) revert SS_NotAuthorized();

    _record.topHatId = topHatId;
  }

  /// @inheritdoc ISquadSponsorFactory
  function addPaymasterStake(uint32 unstakeDelaySec) external payable {
    if (msg.value == 0) revert SS_ZeroAmount();

    address _staker = paymasterStaker;
    if (_staker == address(0)) {
      if (msg.value < MIN_PAYMASTER_STAKE_WEI) {
        revert SS_StakeTooSmall(msg.value, MIN_PAYMASTER_STAKE_WEI);
      }
      if (unstakeDelaySec < MIN_UNSTAKE_DELAY_SEC) {
        revert SS_UnstakeDelayTooShort(unstakeDelaySec, MIN_UNSTAKE_DELAY_SEC);
      }
      paymasterStaker = msg.sender;
      _staker = msg.sender;
    } else if (msg.sender != _staker) {
      revert SS_StakeSlotOccupied(_staker);
    }

    PactoSponsorPaymaster(payable(PAYMASTER)).addStake{value: msg.value}(unstakeDelaySec);
    emit PaymasterStakeAdded(_staker, msg.value, unstakeDelaySec);
  }

  /// @inheritdoc ISquadSponsorFactory
  function unlockPaymasterStake() external {
    _onlyPaymasterStaker();
    PactoSponsorPaymaster(payable(PAYMASTER)).unlockStake();
    emit PaymasterStakeUnlocked(msg.sender);
  }

  /// @inheritdoc ISquadSponsorFactory
  function withdrawPaymasterStake(address payable to) external {
    _onlyPaymasterStaker();
    if (to == address(0)) revert SS_ZeroAddress();

    address _staker = msg.sender;
    PactoSponsorPaymaster(payable(PAYMASTER)).withdrawStake(to);
    paymasterStaker = address(0);
    emit PaymasterStakeWithdrawn(_staker, to);
  }

  /// @inheritdoc ISquadSponsorFactory
  function withdrawPaymasterDeposit(address payable to, uint256 amount) external {
    _onlyPaymasterStaker();
    if (to == address(0)) revert SS_ZeroAddress();
    if (amount == 0) revert SS_ZeroAmount();

    PactoSponsorPaymaster(payable(PAYMASTER)).withdrawTo(to, amount);
    emit PaymasterDepositWithdrawn(msg.sender, to, amount);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  function squads(bytes32 squadId) external view returns (SquadRecord memory record) {
    record = _squads[squadId];
  }

  /// @inheritdoc ISquadSponsorFactory
  function predictWarGameSponsor(bytes32 parentSquadId, uint256 round) external view returns (address sponsor) {
    sponsor = Clones.predictDeterministicAddress(extImplementation, warGameSquadId(parentSquadId, round));
  }

  /// @inheritdoc ISquadSponsorFactory
  function hats() external pure returns (address _hats) {
    _hats = SquadSponsorConstants.HATS_ADDRESS;
  }

  /// @inheritdoc ISquadSponsorFactory
  function warGameSquadId(bytes32 parentSquadId, uint256 round) public pure returns (bytes32 gameSquadId) {
    gameSquadId = keccak256(abi.encode(parentSquadId, WAR_GAME_NS, round));
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Records a newly deployed sponsor clone in the factory registry.
   * @param squadId Squad identifier.
   * @param sponsor New clone address.
   * @param variant Which implementation was deployed.
   * @param topHatId Linked top hat id (zero until wired on Ext clones).
   * @param addressOwner Ext: configured admin. Hats: deployer (`msg.sender`).
   */
  function _registerSquad(
    bytes32 squadId,
    address sponsor,
    SquadVariant variant,
    uint256 topHatId,
    address addressOwner
  ) internal {
    _squads[squadId] = SquadRecord({sponsor: sponsor, variant: variant, topHatId: topHatId});
    squadIdBySponsor[sponsor] = squadId;
    emit SquadCreated(squadId, sponsor, variant, addressOwner);
  }

  /**
   * @notice Forwards optional ETH sent with create calls into the new clone pool.
   * @param sponsor New clone address.
   */
  function _depositIfAny(address sponsor) internal {
    if (msg.value > 0) {
      ISquadSponsorBase(payable(sponsor)).depositFor{value: msg.value}(msg.sender);
    }
  }

  /**
   * @notice Reverts unless `msg.sender` holds the FCFS paymaster stake slot.
   */
  function _onlyPaymasterStaker() internal view {
    if (msg.sender != paymasterStaker) revert SS_NotPaymasterStaker();
  }
}
