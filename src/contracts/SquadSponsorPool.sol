// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ETHTransfer} from 'contracts/utils/ETHTransfer.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';
import {ISquadSponsorPool} from 'interfaces/ISquadSponsorPool.sol';

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';

/**
 * @title SquadSponsorPool
 * @author Pacto
 * @notice Per-parent ETH vault with pro-rata shares and two spend slots (defacto / wargame).
 * @dev Deploy behind an EIP-1167 minimal proxy. Slot-update auth (`onlySlotAdmin`) is deferred.
 */
contract SquadSponsorPool is ISquadSponsorPool, Initializable {
  /// @inheritdoc ISquadSponsorPool
  bytes32 public parentSquadId;
  /// @inheritdoc ISquadSponsorPool
  address public paymaster;
  /// @inheritdoc ISquadSponsorPool
  address public factory;
  /// @inheritdoc ISquadSponsorPool
  uint256 public totalShares;
  /// @inheritdoc ISquadSponsorPool
  mapping(address sponsor => uint256 shares) public sponsorShares;
  /// @notice Storage-backed pool wei available for sponsorship (no BALANCE opcode).
  uint256 internal _spendablePoolWei;
  /// @inheritdoc ISquadSponsorPool
  address public defacto;
  /// @inheritdoc ISquadSponsorPool
  address public wargame;

  /*///////////////////////////////////////////////////////////////
                            MODIFIERS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Placeholder for pool slot-update access control.
   * @dev Empty until the operator / hats-admin design is finalized. `setDefacto` / `setWargame`
   *      remain callable by anyone besides the structural checks in those functions.
   */
  modifier onlySlotAdmin() {
    _;
  }

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Locks direct use of the implementation; clones must call `initialize`.
  constructor() {
    _disableInitializers();
  }

  /// @notice Credits plain ETH sends to `msg.sender` via the same pro-rata path as `deposit`.
  receive() external payable {
    _deposit(msg.sender);
  }

  /// @notice Credits ETH sent with calldata to `msg.sender` via the same pro-rata path as `deposit`.
  fallback() external payable {
    _deposit(msg.sender);
  }

  /*///////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorPool
  function initialize(bytes32 _parentSquadId, address _paymaster, address _factory) external initializer {
    if (_parentSquadId == bytes32(0)) revert SS_ZeroField('parentSquadId');
    if (_paymaster == address(0) || _factory == address(0)) revert SS_ZeroAddress();
    parentSquadId = _parentSquadId;
    paymaster = _paymaster;
    factory = _factory;
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorPool
  function deposit() external payable {
    _deposit(msg.sender);
  }

  /// @inheritdoc ISquadSponsorPool
  function depositFor(address sponsor) external payable {
    if (sponsor == address(0)) revert SS_ZeroAddress();
    _deposit(sponsor);
  }

  /// @inheritdoc ISquadSponsorPool
  function withdraw() external {
    uint256 _shares = sponsorShares[msg.sender];
    if (_shares == 0) revert SS_NoShares();

    uint256 _pool = _spendablePoolWei;
    uint256 _amount = (_shares * _pool) / totalShares;

    sponsorShares[msg.sender] = 0;
    totalShares -= _shares;
    _spendablePoolWei = _pool - _amount;

    ETHTransfer.sendEth(msg.sender, _amount);

    emit Withdrawn(msg.sender, _amount, _shares);
  }

  /// @inheritdoc ISquadSponsorPool
  function spendGas(uint256 amount) external {
    if (msg.sender != paymaster) revert SS_NotPaymaster();
    if (amount > _spendablePoolWei) revert SS_InsufficientBalance();

    _spendablePoolWei -= amount;
    ETHTransfer.sendEth(paymaster, amount);

    emit GasSpent(msg.sender, amount);
  }

  /// @inheritdoc ISquadSponsorPool
  function setDefacto(address sponsor) external onlySlotAdmin {
    _requireSlotSponsor(sponsor);
    defacto = sponsor;
    emit DefactoSet(address(this), sponsor);
  }

  /// @inheritdoc ISquadSponsorPool
  function setWargame(address sponsor) external onlySlotAdmin {
    _requireSlotSponsor(sponsor);
    wargame = sponsor;
    emit WargameSet(address(this), sponsor);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorPool
  function spendablePoolWei() external view returns (uint256 amount) {
    amount = _spendablePoolWei;
  }

  /// @inheritdoc ISquadSponsorPool
  function withdrawable(address sponsor) external view returns (uint256 amount) {
    uint256 _shares = sponsorShares[sponsor];
    if (_shares == 0 || totalShares == 0) return 0;
    amount = (_shares * _spendablePoolWei) / totalShares;
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Mints pro-rata sponsor shares for `sponsor`.
   * @param sponsor Account receiving sponsor shares.
   */
  function _deposit(address sponsor) internal {
    if (msg.value == 0) revert SS_ZeroAmount();

    uint256 _shares;
    uint256 _balanceBefore = _spendablePoolWei;

    if (totalShares != 0 && _balanceBefore != 0) {
      _shares = (msg.value * totalShares) / _balanceBefore;
    } else {
      _shares = msg.value;
    }

    sponsorShares[sponsor] += _shares;
    totalShares += _shares;
    _spendablePoolWei = _balanceBefore + msg.value;

    emit Deposited(sponsor, msg.value, _shares);
  }

  /**
   * @notice Reverts unless `sponsor` is a factory-registered clone wired to this pool.
   * @param sponsor Candidate slot occupant.
   */
  function _requireSlotSponsor(address sponsor) internal view {
    if (sponsor == address(0)) revert SS_ZeroAddress();
    if (ISquadSponsorBase(sponsor).pool() != address(this)) revert SS_PoolMismatch();
    if (ISquadSponsorFactory(factory).squadIdBySponsor(sponsor) == bytes32(0)) revert SS_UnknownSponsor();
  }
}
