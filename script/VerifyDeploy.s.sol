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
 *      Verifies factory, paymaster, and EIP-1167 master copies (`sponsorImplementation`, `extImplementation`).
 *      Once master copies are verified, app-created clones (EIP-1167) are recognized by Etherscan automatically.
 */
contract VerifyDeploy is Script {
  using stdJson for string;

  error UnsupportedChain(uint256 chainId);

  string internal constant _FACTORY = 'src/contracts/SquadSponsorFactory.sol:SquadSponsorFactory';
  string internal constant _PAYMASTER = 'src/contracts/PactoSponsorPaymaster.sol:PactoSponsorPaymaster';
  string internal constant _SPONSOR = 'src/contracts/SquadSponsor.sol:SquadSponsor';
  string internal constant _EXT = 'src/contracts/SquadSponsorExt.sol:SquadSponsorExt';

  function run() external {
    string memory _chain = _chainSlug();
    string memory _path = string.concat('deployments/', vm.toString(block.chainid), '/full-system.json');
    string memory _json = vm.readFile(_path);

    address _entryPoint = _json.readAddress('.entryPoint');
    address _factory = _json.readAddress('.squadSponsorFactory');
    ISquadSponsorFactory _factoryContract = ISquadSponsorFactory(_factory);
    bytes memory _encFactory = abi.encode(IEntryPoint(_entryPoint));
    bytes memory _encPaymaster = abi.encode(IEntryPoint(_entryPoint), _factoryContract);
    bytes memory _encEmpty = new bytes(0);

    console.log('Verifying sponsor contracts on', _chain);

    _verify(_factory, _FACTORY, _chain, _encFactory);
    _verify(_json.readAddress('.pactoSponsorPaymaster'), _PAYMASTER, _chain, _encPaymaster);
    _verify(_factoryContract.sponsorImplementation(), _SPONSOR, _chain, _encEmpty);
    _verify(_factoryContract.extImplementation(), _EXT, _chain, _encEmpty);
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
