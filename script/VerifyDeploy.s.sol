// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

/**
 * @title VerifyDeploy
 * @author Pacto
 * @notice Etherscan verification for sponsor bootstrap contracts from `deployments/<chainId>/full-system.json`.
 * @dev Requires `FOUNDRY_PROFILE=verify` (`ffi = true` in `[profile.verify]` only). Run after `Deploy`.
 */
contract VerifyDeploy is Script {
  using stdJson for string;

  error UnsupportedChain(uint256 chainId);

  string internal constant _FACTORY = 'src/contracts/SquadSponsorFactory.sol:SquadSponsorFactory';
  string internal constant _PAYMASTER = 'src/contracts/PactoSponsorPaymaster.sol:PactoSponsorPaymaster';

  function run() external {
    string memory _chain = _chainSlug();
    string memory _path = string.concat('deployments/', vm.toString(block.chainid), '/full-system.json');
    string memory _json = vm.readFile(_path);

    address _entryPoint = _json.readAddress('.entryPoint');
    address _factory = _json.readAddress('.squadSponsorFactory');
    bytes memory _encFactory = abi.encode(IEntryPoint(_entryPoint));
    bytes memory _encPaymaster = abi.encode(IEntryPoint(_entryPoint), ISquadSponsorFactory(_factory));

    console.log('Verifying sponsor contracts on', _chain);

    _verify(_factory, _FACTORY, _chain, _encFactory);
    _verify(_json.readAddress('.pactoSponsorPaymaster'), _PAYMASTER, _chain, _encPaymaster);
  }

  function _verify(address addr, string memory contractId, string memory chain, bytes memory constructorArgs) internal {
    console.log('==>', contractId, addr);
    string[] memory _inputs = new string[](9);
    _inputs[0] = 'forge';
    _inputs[1] = 'verify-contract';
    _inputs[2] = vm.toString(addr);
    _inputs[3] = contractId;
    _inputs[4] = '--chain';
    _inputs[5] = chain;
    _inputs[6] = '--constructor-args';
    _inputs[7] = vm.toString(constructorArgs);
    _inputs[8] = '--watch';
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
