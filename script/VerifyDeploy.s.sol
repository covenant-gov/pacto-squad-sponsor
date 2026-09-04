// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from 'forge-std/Script.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {console} from 'forge-std/console.sol';

import {IEntryPoint} from '@account-abstraction/interfaces/IEntryPoint.sol';
import {IPactoSponsorPaymaster} from 'interfaces/IPactoSponsorPaymaster.sol';
import {ISquadSponsorFactory} from 'interfaces/ISquadSponsorFactory.sol';

/**
 * @title VerifyDeploy
 * @author Pacto
 * @notice Etherscan verification for sponsor bootstrap contracts from `deployments/<chainId>/full-system.json`.
 * @dev Requires `FOUNDRY_PROFILE=verify` (`ffi = true` in `[profile.verify]` only). Run after `Deploy`.
 *      Verifies factory, paymaster, and EIP-1167 master copies (`sponsorImplementation`, `extImplementation`, `poolImplementation`).
 *      Once master copies are verified, app-created clones (EIP-1167) are recognized by Etherscan automatically.
 *      Also asserts on-chain `ALLOWED_7702_IMPLEMENTATION` matches the 7702 artifact / `PACTO_7702_ACCOUNT`.
 */
contract VerifyDeploy is Script {
  using stdJson for string;

  error UnsupportedChain(uint256 chainId);
  error VerifyDeploy_Zero7702Allowlist();
  error VerifyDeploy_AllowlistMismatch(address onChain, address expected);

  string internal constant _FACTORY = 'src/contracts/SquadSponsorFactory.sol:SquadSponsorFactory';
  string internal constant _PAYMASTER = 'src/contracts/PactoSponsorPaymaster.sol:PactoSponsorPaymaster';
  string internal constant _SPONSOR = 'src/contracts/SquadSponsor.sol:SquadSponsor';
  string internal constant _EXT = 'src/contracts/SquadSponsorExt.sol:SquadSponsorExt';
  string internal constant _POOL = 'src/contracts/SquadSponsorPool.sol:SquadSponsorPool';

  function run() external {
    string memory _chain = _chainSlug();
    string memory _path = string.concat('deployments/', vm.toString(block.chainid), '/full-system.json');
    string memory _json = vm.readFile(_path);

    address _entryPoint = _json.readAddress('.entryPoint');
    address _factory = _json.readAddress('.squadSponsorFactory');
    address _paymaster = _json.readAddress('.pactoSponsorPaymaster');
    ISquadSponsorFactory _factoryContract = ISquadSponsorFactory(_factory);
    address _allowed7702 = _resolveExpected7702();
    if (_allowed7702 == address(0)) revert VerifyDeploy_Zero7702Allowlist();

    address _onChainAllowlist = IPactoSponsorPaymaster(_paymaster).ALLOWED_7702_IMPLEMENTATION();
    if (_onChainAllowlist != _allowed7702) {
      revert VerifyDeploy_AllowlistMismatch(_onChainAllowlist, _allowed7702);
    }
    console.log('ALLOWED_7702_IMPLEMENTATION ok:', _onChainAllowlist);

    bytes memory _encFactory = abi.encode(IEntryPoint(_entryPoint), _allowed7702);
    bytes memory _encPaymaster = abi.encode(IEntryPoint(_entryPoint), _factoryContract, _allowed7702);
    bytes memory _encEmpty = new bytes(0);

    console.log('Verifying sponsor contracts on', _chain);

    _verify(_factory, _FACTORY, _chain, _encFactory);
    _verify(_paymaster, _PAYMASTER, _chain, _encPaymaster);
    _verify(_factoryContract.sponsorImplementation(), _SPONSOR, _chain, _encEmpty);
    _verify(_factoryContract.extImplementation(), _EXT, _chain, _encEmpty);
    _verify(_factoryContract.poolImplementation(), _POOL, _chain, _encEmpty);
  }

  /// @dev Prefer mirrored `eip7702-account.json` (from pacto-aa), then `PACTO_7702_ACCOUNT`.
  function _resolveExpected7702() internal view returns (address allowed7702) {
    string memory eip7702Path = string.concat('deployments/', vm.toString(block.chainid), '/eip7702-account.json');
    try vm.readFile(eip7702Path) returns (string memory eip7702Json) {
      allowed7702 = eip7702Json.readAddress('.pactoSimple7702Account');
    } catch {}
    if (allowed7702 != address(0)) return allowed7702;
    allowed7702 = vm.envOr('PACTO_7702_ACCOUNT', address(0));
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
