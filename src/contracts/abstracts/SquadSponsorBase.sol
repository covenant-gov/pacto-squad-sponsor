// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ETHTransfer} from 'contracts/utils/ETHTransfer.sol';
import {SquadSponsorConstants} from 'contracts/utils/constants/SquadSponsorConstants.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title SquadSponsorBase
 * @author Pacto
 * @notice Shared per-squad ETH pool, pro-rata sponsor shares, and paymaster-only gas spend.
 */
abstract contract SquadSponsorBase is ISquadSponsorBase, Initializable {
  /// @notice Hats Protocol singleton for eligibility checks.
  IHats internal constant _HATS = IHats(SquadSponsorConstants.HATS_ADDRESS);

  /// @inheritdoc ISquadSponsorBase
  bytes32 public squadId;
  /// @inheritdoc ISquadSponsorBase
  address public paymaster;
  /// @inheritdoc ISquadSponsorBase
  address public factory;
  /// @inheritdoc ISquadSponsorBase
  uint256 public totalShares;
  /// @inheritdoc ISquadSponsorBase
  mapping(address sponsor => uint256 shares) public sponsorShares;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Locks direct use of the implementation; clones must call a child `initialize`.
  constructor() {
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @notice Credits plain ETH sends to `msg.sender` via the same pro-rata path as `deposit`.
  receive() external payable {
    _deposit(msg.sender);
  }

  /// @notice Credits ETH sent with calldata to `msg.sender` via the same pro-rata path as `deposit`.
  fallback() external payable {
    _deposit(msg.sender);
  }

  /// @inheritdoc ISquadSponsorBase
  function deposit() external payable {
    _deposit(msg.sender);
  }

  /// @inheritdoc ISquadSponsorBase
  function depositFor(address sponsor) external payable {
    if (sponsor == address(0)) revert SS_ZeroAddress();
    _deposit(sponsor);
  }

  /// @inheritdoc ISquadSponsorBase
  function withdraw() external {
    uint256 _shares = sponsorShares[msg.sender];
    if (_shares == 0) revert SS_NoShares();

    uint256 _balance = address(this).balance;
    uint256 _amount = (_shares * _balance) / totalShares;

    sponsorShares[msg.sender] = 0;
    totalShares -= _shares;

    ETHTransfer.sendEth(msg.sender, _amount);

    emit Withdrawn(msg.sender, _amount, _shares);
  }

  /// @inheritdoc ISquadSponsorBase
  function spendGas(uint256 amount) external {
    if (msg.sender != paymaster) revert SS_NotPaymaster();
    if (amount > address(this).balance) revert SS_InsufficientBalance();

    ETHTransfer.sendEth(paymaster, amount);

    emit GasSpent(msg.sender, amount);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorBase
  function isEligible(address member) external view returns (bool eligible) {
    eligible = _isEligible(member);
  }

  /// @inheritdoc ISquadSponsorBase
  function withdrawable(address sponsor) external view returns (uint256 amount) {
    uint256 _shares = sponsorShares[sponsor];
    if (_shares == 0 || totalShares == 0) return 0;
    amount = (_shares * address(this).balance) / totalShares;
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Seeds shared sponsor clone fields.
   * @param _squadId Squad identifier bound to this clone.
   * @param _paymaster Chain paymaster authorized to call `spendGas`.
   * @param _factory SquadSponsorFactory address.
   */
  function _sponsorBaseInit(bytes32 _squadId, address _paymaster, address _factory) internal {
    if (_paymaster == address(0) || _factory == address(0)) revert SS_ZeroAddress();
    squadId = _squadId;
    paymaster = _paymaster;
    factory = _factory;
  }

  /**
   * @notice Mints pro-rata sponsor shares for `sponsor`.
   * @param sponsor Account receiving sponsor shares.
   */
  function _deposit(address sponsor) internal {
    if (msg.value == 0) revert SS_ZeroAmount();

    uint256 _shares;
    uint256 _balanceBefore = address(this).balance - msg.value;

    if (totalShares != 0 && _balanceBefore != 0) {
      _shares = (msg.value * totalShares) / _balanceBefore;
    } else {
      _shares = msg.value;
    }

    sponsorShares[sponsor] += _shares;
    totalShares += _shares;

    emit Deposited(sponsor, msg.value, _shares);
  }

  /**
   * @notice Returns whether `member` may have squad gas sponsored.
   * @param member Address evaluated for sponsorship eligibility.
   * @return eligible True when the member qualifies under this clone's rules.
   */
  function _isEligible(address member) internal view virtual returns (bool eligible);
}
