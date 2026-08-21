// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {PactoSponsorPaymaster} from 'contracts/PactoSponsorPaymaster.sol';
import {SquadSponsor} from 'contracts/SquadSponsor.sol';
import {SquadSponsorExt} from 'contracts/SquadSponsorExt.sol';
import {SquadSponsorPool} from 'contracts/SquadSponsorPool.sol';
import {SquadSponsorConstants} from 'contracts/utils/constants/SquadSponsorConstants.sol';

import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';
import {ISquadSponsorPool} from 'interfaces/ISquadSponsorPool.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';

import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

/**
 * @title SquadSponsorFactory
 * @author Pacto
 * @notice Chain singleton that deploys per-squad pools, sponsor clones, and its wired paymaster.
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
  address public poolImplementation;

  /// @inheritdoc ISquadSponsorFactory
  address public paymasterStaker;

  /// @notice Per-squad registry rows keyed by squad id.
  mapping(bytes32 squadId => SquadRecord record) internal _squads;
  /// @inheritdoc ISquadSponsorFactory
  mapping(address sponsor => bytes32 squadId) public squadIdBySponsor;

  /// @inheritdoc ISquadSponsorFactory
  mapping(bytes32 parentSquadId => uint256 count) public warGameRoundCount;

  /// @inheritdoc ISquadSponsorFactory
  mapping(bytes32 parentSquadId => address pool) public poolOf;
  /// @inheritdoc ISquadSponsorFactory
  mapping(bytes32 parentSquadId => uint256 nonce) public poolNonce;

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
    poolImplementation = address(new SquadSponsorPool());
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsorExt(bytes32 squadId, address addressOwner) external payable returns (address sponsor) {
    sponsor = _createSquadSponsorExt(squadId, addressOwner, address(0));
  }

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsorExt(
    bytes32 squadId,
    address addressOwner,
    address pool
  ) external payable returns (address sponsor) {
    sponsor = _createSquadSponsorExt(squadId, addressOwner, pool);
  }

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external payable returns (address sponsor) {
    sponsor = _createSquadSponsor(squadId, topHatId, registry, customEligibleHats, address(0));
  }

  /// @inheritdoc ISquadSponsorFactory
  function createSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats,
    address pool
  ) external payable returns (address sponsor) {
    sponsor = _createSquadSponsor(squadId, topHatId, registry, customEligibleHats, pool);
  }

  /// @inheritdoc ISquadSponsorFactory
  function createWarGameSponsor(
    bytes32 parentSquadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats
  ) external payable returns (address sponsor, uint256 round, bytes32 gameSquadId) {
    (sponsor, round, gameSquadId) =
      _createWarGameSponsor(parentSquadId, topHatId, registry, customEligibleHats, address(0));
  }

  /// @inheritdoc ISquadSponsorFactory
  function createWarGameSponsor(
    bytes32 parentSquadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats,
    address pool
  ) external payable returns (address sponsor, uint256 round, bytes32 gameSquadId) {
    (sponsor, round, gameSquadId) = _createWarGameSponsor(parentSquadId, topHatId, registry, customEligibleHats, pool);
  }

  /// @inheritdoc ISquadSponsorFactory
  function createWarGameSponsorExt(
    bytes32 parentSquadId,
    address addressOwner
  ) external payable returns (address sponsor, uint256 round, bytes32 gameSquadId) {
    (sponsor, round, gameSquadId) = _createWarGameSponsorExt(parentSquadId, addressOwner, address(0));
  }

  /// @inheritdoc ISquadSponsorFactory
  function createWarGameSponsorExt(
    bytes32 parentSquadId,
    address addressOwner,
    address pool
  ) external payable returns (address sponsor, uint256 round, bytes32 gameSquadId) {
    (sponsor, round, gameSquadId) = _createWarGameSponsorExt(parentSquadId, addressOwner, pool);
  }

  /// @inheritdoc ISquadSponsorFactory
  function createPool(bytes32 parentSquadId) external returns (address pool) {
    pool = _createPrimaryPool(parentSquadId);
  }

  /// @inheritdoc ISquadSponsorFactory
  function createFreshPool(bytes32 parentSquadId) external returns (address pool) {
    if (parentSquadId == bytes32(0)) revert SS_ZeroField('parentSquadId');

    uint256 _nonce = ++poolNonce[parentSquadId];
    bytes32 _salt = keccak256(abi.encode(parentSquadId, _nonce));
    pool = _deployPool(parentSquadId, _salt);

    bool _primary = poolOf[parentSquadId] == address(0);
    if (_primary) poolOf[parentSquadId] = pool;
    emit PoolCreated(parentSquadId, pool, _primary);
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
  function predictWarGameHatsSponsor(bytes32 parentSquadId, uint256 round) external view returns (address sponsor) {
    sponsor = Clones.predictDeterministicAddress(sponsorImplementation, warGameSquadId(parentSquadId, round));
  }

  /// @inheritdoc ISquadSponsorFactory
  function predictPool(bytes32 parentSquadId) external view returns (address pool) {
    pool = Clones.predictDeterministicAddress(poolImplementation, parentSquadId);
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
   * @notice Deploys a production Ext clone, wires it to a pool, and sets `defacto`.
   * @param squadId Production squad identifier.
   * @param addressOwner Ext address-list admin.
   * @param pool Existing pool or `address(0)` for the primary pool.
   * @return sponsor New Ext clone address.
   */
  function _createSquadSponsorExt(
    bytes32 squadId,
    address addressOwner,
    address pool
  ) internal returns (address sponsor) {
    if (_squads[squadId].sponsor != address(0)) revert SS_SquadAlreadyExists(squadId);
    if (addressOwner == address(0)) revert SS_ZeroAddress();

    address _resolvedPool = _resolvePool(squadId, pool);
    sponsor = Clones.clone(extImplementation);
    SquadSponsorExt(payable(sponsor)).initialize(squadId, address(this), _resolvedPool, addressOwner);

    _registerSquad(squadId, sponsor, SquadVariant.EXT, 0, addressOwner, _resolvedPool);
    ISquadSponsorPool(payable(_resolvedPool)).setDefacto(sponsor);
    _depositIfAny(_resolvedPool);
  }

  /**
   * @notice Deploys a production hats clone, wires it to a pool, and sets `defacto`.
   * @param squadId Production squad identifier.
   * @param topHatId Linked top hat id.
   * @param registry PactoGov registry (`address(0)` for custom hats only).
   * @param customEligibleHats Custom eligible hat ids.
   * @param pool Existing pool or `address(0)` for the primary pool.
   * @return sponsor New SquadSponsor clone address.
   */
  function _createSquadSponsor(
    bytes32 squadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats,
    address pool
  ) internal returns (address sponsor) {
    if (_squads[squadId].sponsor != address(0)) revert SS_SquadAlreadyExists(squadId);

    address _resolvedPool = _resolvePool(squadId, pool);
    sponsor = Clones.clone(sponsorImplementation);
    SquadSponsor(payable(sponsor))
      .initialize(squadId, address(this), _resolvedPool, topHatId, registry, customEligibleHats);

    _registerSquad(squadId, sponsor, SquadVariant.SPONSOR, topHatId, msg.sender, _resolvedPool);
    ISquadSponsorPool(payable(_resolvedPool)).setDefacto(sponsor);
    _depositIfAny(_resolvedPool);
  }

  /**
   * @notice Deploys a hats-native war-game round clone and sets `wargame`.
   * @param parentSquadId Production squad identifier.
   * @param topHatId Linked top hat id.
   * @param registry PactoGov / war-game registry.
   * @param customEligibleHats Custom eligible hat ids.
   * @param pool Existing pool or `address(0)` for the primary pool.
   * @return sponsor New round clone address.
   * @return round 1-indexed round.
   * @return gameSquadId Derived registry id.
   */
  function _createWarGameSponsor(
    bytes32 parentSquadId,
    uint256 topHatId,
    address registry,
    uint256[] calldata customEligibleHats,
    address pool
  ) internal returns (address sponsor, uint256 round, bytes32 gameSquadId) {
    if (parentSquadId == bytes32(0)) revert SS_ZeroField('parentSquadId');

    (round, gameSquadId) = _nextWarGameRound(parentSquadId);
    address _resolvedPool = _resolvePool(parentSquadId, pool);

    sponsor = Clones.cloneDeterministic(sponsorImplementation, gameSquadId);
    SquadSponsor(payable(sponsor))
      .initialize(gameSquadId, address(this), _resolvedPool, topHatId, registry, customEligibleHats);

    _registerSquad(gameSquadId, sponsor, SquadVariant.SPONSOR, topHatId, msg.sender, _resolvedPool);
    ISquadSponsorPool(payable(_resolvedPool)).setWargame(sponsor);
    _depositIfAny(_resolvedPool);
    emit WarGameSponsorCreated(parentSquadId, round, gameSquadId, sponsor);
  }

  /**
   * @notice Deploys an Ext war-game round clone and sets `wargame`.
   * @param parentSquadId Production squad identifier.
   * @param addressOwner Ext address-list admin.
   * @param pool Existing pool or `address(0)` for the primary pool.
   * @return sponsor New round clone address.
   * @return round 1-indexed round.
   * @return gameSquadId Derived registry id.
   */
  function _createWarGameSponsorExt(
    bytes32 parentSquadId,
    address addressOwner,
    address pool
  ) internal returns (address sponsor, uint256 round, bytes32 gameSquadId) {
    if (parentSquadId == bytes32(0)) revert SS_ZeroField('parentSquadId');
    if (addressOwner == address(0)) revert SS_ZeroAddress();

    (round, gameSquadId) = _nextWarGameRound(parentSquadId);
    address _resolvedPool = _resolvePool(parentSquadId, pool);

    sponsor = Clones.cloneDeterministic(extImplementation, gameSquadId);
    SquadSponsorExt(payable(sponsor)).initialize(gameSquadId, address(this), _resolvedPool, addressOwner);

    _registerSquad(gameSquadId, sponsor, SquadVariant.EXT, 0, addressOwner, _resolvedPool);
    ISquadSponsorPool(payable(_resolvedPool)).setWargame(sponsor);
    _depositIfAny(_resolvedPool);
    emit WarGameSponsorCreated(parentSquadId, round, gameSquadId, sponsor);
  }

  /**
   * @notice Assigns the next war-game round for `parentSquadId`.
   * @param parentSquadId Production squad identifier.
   * @return round 1-indexed round.
   * @return gameSquadId Derived registry id.
   */
  function _nextWarGameRound(bytes32 parentSquadId) internal returns (uint256 round, bytes32 gameSquadId) {
    round = ++warGameRoundCount[parentSquadId];
    gameSquadId = warGameSquadId(parentSquadId, round);
    if (_squads[gameSquadId].sponsor != address(0)) revert SS_SquadAlreadyExists(gameSquadId);
  }

  /**
   * @notice Resolves `pool` or get-or-creates the primary pool for `parentSquadId`.
   * @param parentSquadId Production squad identifier.
   * @param pool Caller-supplied pool or `address(0)`.
   * @return resolved Pool address to wire.
   */
  function _resolvePool(bytes32 parentSquadId, address pool) internal returns (address resolved) {
    if (pool == address(0)) return _createPrimaryPool(parentSquadId);
    if (ISquadSponsorPool(pool).factory() != address(this)) revert SS_PoolMismatch();
    if (ISquadSponsorPool(pool).parentSquadId() != parentSquadId) revert SS_PoolParentMismatch();
    resolved = pool;
  }

  /**
   * @notice Returns the primary pool, deploying it if missing.
   * @param parentSquadId Production squad identifier.
   * @return pool Primary pool address.
   */
  function _createPrimaryPool(bytes32 parentSquadId) internal returns (address pool) {
    if (parentSquadId == bytes32(0)) revert SS_ZeroField('parentSquadId');
    pool = poolOf[parentSquadId];
    if (pool != address(0)) return pool;

    pool = _deployPool(parentSquadId, parentSquadId);
    poolOf[parentSquadId] = pool;
    emit PoolCreated(parentSquadId, pool, true);
  }

  /**
   * @notice Clones and initializes a pool with CREATE2 salt `salt`.
   * @param parentSquadId Production squad identifier.
   * @param salt CREATE2 salt.
   * @return pool New pool clone.
   */
  function _deployPool(bytes32 parentSquadId, bytes32 salt) internal returns (address pool) {
    pool = Clones.cloneDeterministic(poolImplementation, salt);
    SquadSponsorPool(payable(pool)).initialize(parentSquadId, PAYMASTER, address(this));
  }

  /**
   * @notice Records a newly deployed sponsor clone in the factory registry.
   * @param squadId Squad identifier.
   * @param sponsor New clone address.
   * @param variant Which implementation was deployed.
   * @param topHatId Linked top hat id (zero until wired on Ext clones).
   * @param addressOwner Ext: configured admin. Hats: deployer (`msg.sender`).
   * @param pool Parent pool this clone spends from.
   */
  function _registerSquad(
    bytes32 squadId,
    address sponsor,
    SquadVariant variant,
    uint256 topHatId,
    address addressOwner,
    address pool
  ) internal {
    _squads[squadId] = SquadRecord({sponsor: sponsor, variant: variant, topHatId: topHatId, pool: pool});
    squadIdBySponsor[sponsor] = squadId;
    emit SquadCreated(squadId, sponsor, variant, addressOwner);
  }

  /**
   * @notice Forwards optional ETH sent with create calls into the resolved pool.
   * @param pool Pool to credit.
   */
  function _depositIfAny(address pool) internal {
    if (msg.value > 0) {
      ISquadSponsorPool(payable(pool)).depositFor{value: msg.value}(msg.sender);
    }
  }

  /**
   * @notice Reverts unless `msg.sender` holds the FCFS paymaster stake slot.
   */
  function _onlyPaymasterStaker() internal view {
    if (msg.sender != paymasterStaker) revert SS_NotPaymasterStaker();
  }
}
