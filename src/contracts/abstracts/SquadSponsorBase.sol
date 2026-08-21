// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorConstants} from 'contracts/utils/constants/SquadSponsorConstants.sol';

import {ISquadSponsorBase} from 'interfaces/ISquadSponsorBase.sol';
import {ISquadSponsorPool} from 'interfaces/ISquadSponsorPool.sol';

import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title SquadSponsorBase
 * @author Pacto
 * @notice Shared per-squad eligibility clone bound to a parent `SquadSponsorPool`.
 */
abstract contract SquadSponsorBase is ISquadSponsorBase, Initializable {
  /// @notice Hats Protocol singleton for eligibility checks.
  IHats internal constant _HATS = IHats(SquadSponsorConstants.HATS_ADDRESS);

  /// @inheritdoc ISquadSponsorBase
  bytes32 public squadId;
  /// @inheritdoc ISquadSponsorBase
  address public factory;
  /// @inheritdoc ISquadSponsorBase
  address public pool;

  /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Locks direct use of the implementation; clones must call a child `initialize`.
  constructor() {
    _disableInitializers();
  }

  /*///////////////////////////////////////////////////////////////
                            VIEWS
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ISquadSponsorBase
  function isEligible(address member) external view returns (bool eligible) {
    eligible = _isEligible(member);
  }

  /// @inheritdoc ISquadSponsorBase
  function spendablePoolWei() external view returns (uint256 amount) {
    amount = ISquadSponsorPool(pool).spendablePoolWei();
  }

  /// @inheritdoc ISquadSponsorBase
  function paymaster() external view returns (address paymaster_) {
    paymaster_ = ISquadSponsorPool(pool).paymaster();
  }

  /*///////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Seeds shared sponsor clone fields.
   * @param _squadId Squad identifier bound to this clone.
   * @param _factory SquadSponsorFactory address.
   * @param _pool Parent `SquadSponsorPool` this clone spends from.
   */
  function _sponsorBaseInit(bytes32 _squadId, address _factory, address _pool) internal {
    if (_factory == address(0) || _pool == address(0)) revert SS_ZeroAddress();
    if (ISquadSponsorPool(_pool).factory() != _factory) revert SS_PoolMismatch();
    squadId = _squadId;
    factory = _factory;
    pool = _pool;
  }

  /**
   * @notice Returns whether `member` may have squad gas sponsored.
   * @param member Address evaluated for sponsorship eligibility.
   * @return eligible True when the member qualifies under this clone's rules.
   */
  function _isEligible(address member) internal view virtual returns (bool eligible);
}
