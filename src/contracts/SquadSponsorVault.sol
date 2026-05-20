// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorVault} from 'interfaces/ISquadSponsorVault.sol';

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';

/**
 * @title SquadSponsorVault
 * @author Pacto
 * @notice Per-squad ETH pool with pro-rata sponsor shares; gas spend is paymaster-only.
 * @dev Deploy behind an EIP-1167 minimal proxy (`Clones`); clones call `initialize` once.
 */
contract SquadSponsorVault is ISquadSponsorVault, Initializable {
  /*///////////////////////////////////////////////////////////////
                            STORAGE
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorVault
  bytes32 public squadId;
  /// @inheritdoc ISquadSponsorVault
  address public ext;
  /// @inheritdoc ISquadSponsorVault
  address public paymaster;
  /// @inheritdoc ISquadSponsorVault
  address public factory;
  /// @inheritdoc ISquadSponsorVault
  uint256 public topHatId;
  /// @inheritdoc ISquadSponsorVault
  uint256 public totalShares;
  /// @inheritdoc ISquadSponsorVault
  mapping(address sponsor => uint256 shares) public sponsorShares;

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

  /// @inheritdoc ISquadSponsorVault
  function initialize(bytes32 _squadId, address _ext, address _paymaster, address _factory) external initializer {
    if (_ext == address(0) || _factory == address(0)) revert SquadSponsorVault_ZeroAddress();
    squadId = _squadId;
    ext = _ext;
    paymaster = _paymaster;
    factory = _factory;
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorVault
  function deposit() external payable {
    _deposit(msg.sender);
  }

  /// @inheritdoc ISquadSponsorVault
  function depositFor(address sponsor) external payable {
    if (sponsor == address(0)) revert SquadSponsorVault_ZeroAddress();
    _deposit(sponsor);
  }

  /// @inheritdoc ISquadSponsorVault
  function withdraw() external {
    uint256 _shares = sponsorShares[msg.sender];
    if (_shares == 0) revert SquadSponsorVault_NoShares();

    uint256 _balance = address(this).balance;
    uint256 _amount = (_shares * _balance) / totalShares;

    sponsorShares[msg.sender] = 0;
    totalShares -= _shares;

    (bool _ok,) = msg.sender.call{value: _amount}('');
    if (!_ok) revert SquadSponsorVault_TransferFailed();

    emit Withdrawn(msg.sender, _amount, _shares);
  }

  /// @inheritdoc ISquadSponsorVault
  function spendGas(uint256 amount) external {
    if (msg.sender != paymaster) revert SquadSponsorVault_NotPaymaster();
    if (amount > address(this).balance) revert SquadSponsorVault_InsufficientBalance();

    (bool _ok,) = paymaster.call{value: amount}('');
    if (!_ok) revert SquadSponsorVault_TransferFailed();

    emit GasSpent(msg.sender, amount);
  }

  /// @inheritdoc ISquadSponsorVault
  function linkTopHat(uint256 _topHatId) external {
    if (msg.sender != ext) revert SquadSponsorVault_NotExt();
    if (topHatId != 0) revert SquadSponsorVault_TopHatAlreadyLinked();
    topHatId = _topHatId;
    emit TopHatLinked(_topHatId);
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorVault
  function withdrawable(address sponsor) external view returns (uint256 amount) {
    uint256 _shares = sponsorShares[sponsor];
    if (_shares == 0 || totalShares == 0) return 0;
    amount = (_shares * address(this).balance) / totalShares;
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Mints pro-rata sponsor shares for `sponsor`.
   * @param sponsor Account receiving sponsor shares.
   */
  function _deposit(address sponsor) internal {
    if (msg.value == 0) revert SquadSponsorVault_ZeroAmount();

    uint256 _shares;
    uint256 _balanceBefore = address(this).balance - msg.value;

    if (totalShares == 0 || _balanceBefore == 0) {
      _shares = msg.value;
    } else {
      _shares = (msg.value * totalShares) / _balanceBefore;
    }

    sponsorShares[sponsor] += _shares;
    totalShares += _shares;

    emit Deposited(sponsor, msg.value, _shares);
  }
}
