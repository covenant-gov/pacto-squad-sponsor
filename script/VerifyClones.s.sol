// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

/**
 * @title VerifyClones
 * @author Pacto
 * @notice Etherscan proxy verification for squad sponsor clones listed in `deployments/<chainId>/clones.json`.
 * @dev Requires `FOUNDRY_PROFILE=verify` (`ffi = true`). Run `VerifyDeploy` first so master copies are verified.
 *      Clones are EIP-1167 minimal proxies; Etherscan links them to the verified implementation after proxy verification.
 *
 *      `clones.json` shape: `{ "clones": ["0x...", "0x..."] }`
 *      Populate via `IndexClones` or your app indexer after `SquadCreated` events.
 */
contract VerifyClones is Script {
  error UnsupportedChain(uint256 chainId);
  error MissingClonesFile(string path);

  function run() external {
    string memory _path = string.concat('deployments/', vm.toString(block.chainid), '/clones.json');
    if (!vm.exists(_path)) revert MissingClonesFile(_path);

    string memory _json = vm.readFile(_path);
    address[] memory _clones = abi.decode(vm.parseJson(_json, '.clones'), (address[]));

    console.log('Proxy-verifying', _clones.length, 'squad sponsor clone(s) on chain', block.chainid);

    for (uint256 _i; _i < _clones.length; ++_i) {
      _verifyProxy(_clones[_i]);
    }
  }

  function _verifyProxy(address clone) internal {
    console.log('==> clone', clone);
    string[] memory _inputs = new string[](3);
    _inputs[0] = 'bash';
    _inputs[1] = '-c';
    _inputs[2] = string.concat(
      'curl -sf \"https://api.etherscan.io/v2/api?chainid=',
      vm.toString(block.chainid),
      '&module=contract&action=verifyproxycontract&address=',
      vm.toString(clone),
      '&apikey=${ETHERSCAN_API_KEY}\"'
    );
    console.log(string(vm.ffi(_inputs)));
  }
}
