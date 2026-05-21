// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ISquadSponsorCommon} from 'interfaces/ISquadSponsorCommon.sol';

import {IHats} from 'hats-core/Interfaces/IHats.sol';

/**
 * @title HatWireAuth
 * @author Pacto
 * @notice Shared authorization for Ext hat wiring.
 */
library HatWireAuth {
  /**
   * @notice Reverts unless `sender` is factory, bootstrap owner, or Hats tree admin.
   * @param hats Hats Protocol singleton.
   * @param factory SquadSponsorFactory address.
   * @param bootstrapOwner Ext address owner (`address(0)` once cleared).
   * @param sender Caller being authorized.
   * @param topHatId Top hat id being wired.
   */
  function requireHatWireAuth(
    IHats hats,
    address factory,
    address bootstrapOwner,
    address sender,
    uint256 topHatId
  ) internal view {
    if (sender == factory) return;
    if (bootstrapOwner != address(0) && sender == bootstrapOwner) return;
    if (hats.isAdminOfHat(sender, topHatId)) return;
    revert ISquadSponsorCommon.SS_NotAuthorized();
  }
}
