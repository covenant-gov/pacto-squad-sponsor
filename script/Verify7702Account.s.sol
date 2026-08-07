// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

/**
 * @title Verify7702Account
 * @author Pacto
 * @notice Etherscan verification for `PactoSimple7702Account` from `deployments/<chainId>/eip7702-account.json`.
 * @dev Requires `FOUNDRY_PROFILE=verify`. No constructor args.
 */
contract Verify7702Account is Script {
  using stdJson for string;

  error UnsupportedChain(uint256 chainId);

  string internal constant _ACCOUNT = 'src/contracts/PactoSimple7702Account.sol:PactoSimple7702Account';

  function run() external {
    string memory _chain = _chainSlug();
    string memory _path = string.concat('deployments/', vm.toString(block.chainid), '/eip7702-account.json');
    string memory _json = vm.readFile(_path);

    address _account = _json.readAddress('.pactoSimple7702Account');
    bytes memory _encEmpty = new bytes(0);

    console.log('Verifying PactoSimple7702Account on', _chain);
    _verify(_account, _ACCOUNT, _chain, _encEmpty);
  }

  function _verify(address addr, string memory contractId, string memory chain, bytes memory constructorArgs) internal {
    console.log('==>', contractId, addr);
    string[] memory _inputs = new string[](12);
    _inputs[0] = 'forge';
    _inputs[1] = 'verify-contract';
    _inputs[2] = vm.toString(addr);
    _inputs[3] = contractId;
    _inputs[4] = '--rpc-url';
    _inputs[5] = chain;
    _inputs[6] = '--chain';
    _inputs[7] = chain;
    _inputs[8] = '--constructor-args';
    _inputs[9] = vm.toString(constructorArgs);
    _inputs[10] = '--skip-is-verified-check';
    _inputs[11] = '--watch';
    console.log(string(vm.ffi(_inputs)));
  }

  function _chainSlug() internal view returns (string memory) {
    uint256 _id = block.chainid;
    if (_id == 11_155_111) return 'sepolia';
    if (_id == 1) return 'mainnet';
    if (_id == 42_161) return 'arbitrum';
    revert UnsupportedChain(_id);
  }
}
