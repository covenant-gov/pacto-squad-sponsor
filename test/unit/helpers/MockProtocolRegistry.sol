// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IPactoProtocolRegistry} from 'interfaces/IPactoProtocolRegistry.sol';

/**
 * @title MockProtocolRegistry
 * @author Pacto
 * @notice Minimal mutable registry for unit/integration fixtures.
 */
contract MockProtocolRegistry is IPactoProtocolRegistry {
  address public allowed7702Implementation;

  function setAllowed7702Implementation(address allowed7702) external {
    allowed7702Implementation = allowed7702;
  }
}
