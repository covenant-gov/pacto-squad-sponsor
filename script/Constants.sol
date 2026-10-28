// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorConstants} from 'contracts/utils/constants/SquadSponsorConstants.sol';

/// @dev Hats Protocol v1 — same as `SquadSponsorConstants.HATS_ADDRESS`; fork presence check for integration tests.
address constant HATS_PROTOCOL_V1 = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;

/// @dev Default block pin for `vm.createSelectFork` when `MAINNET_RPC` is set (stable Hats singleton).
uint256 constant DEFAULT_MAINNET_FORK_BLOCK = 22_900_000;

/// @dev Foundry routes `new Contract{salt:}` in broadcast scripts through Nick's CREATE2 deployer.
address constant CREATE2_DEFAULT_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

/// @notice Public chain constants and deployed contract addresses.
/// @dev Private values (RPC URLs, API keys, deployer keystore names) live in `.env` only.
/// @dev Deploy (`script/Deploy.sol`) CREATE2-deploys
/// `SquadSponsorFactory(entryPoint, allowed7702, allowlistAdmin)`. The paymaster stores the allowlist
/// in a storage slot; `ALLOWLIST_ADMIN` may rotate it. Resolve the seed from mirrored
/// `eip7702-account.json` or `PACTO_7702_ACCOUNT`, and the admin from `ALLOWLIST_ADMIN` (live-chain
/// scripts reject `address(0)` for both). `protocol-registry.json` is still recorded so verify can
/// check the seeded allowlist equals `allowed7702Impl()`.
/// Hats is not a constructor arg — it is baked into sponsor bytecode via `SquadSponsorConstants.HATS_ADDRESS`.
/// `navePirataRegistry` is a pacto-gov pin for humans/docs. Deploy must not write it into
/// `full-system.json`; copy gov's registry from `protocol-registry.json` / `PACTO_NAVE_PIRATA_REGISTRY`
/// when present, otherwise omit the key.
library Constants {
  /**
   * @notice Chain-level deployment configuration.
   * @param chainId The supported network's chain ID.
   * @param entryPoint ERC-4337 EntryPoint v0.7 wired into `PactoSponsorPaymaster`.
   * @param navePirataRegistry Pacto-gov registry pin (not a factory constructor arg; Deploy does not persist this).
   * @param safe4337Module Safe 4337 module address for Path A UserOps (integration / app consumption).
   * @param squadSponsorFactory CREATE2-deployed `SquadSponsorFactory` — documentation pin after deploy.
   * @param paymaster CREATE2-deployed `PactoSponsorPaymaster` — documentation pin after deploy.
   * @param mainnetForkBlock Mainnet block pin for integration fork tests (`IntegrationBase`).
   */
  struct ChainConfig {
    uint256 chainId;
    address entryPoint;
    address navePirataRegistry;
    address safe4337Module;
    address squadSponsorFactory;
    address paymaster;
    uint256 mainnetForkBlock;
  }

  /// @notice Returns chain configuration for `chainId`.
  function getConfig(uint256 chainId) internal pure returns (ChainConfig memory config) {
    if (chainId == 1) return _mainnet();
    if (chainId == 11_155_111) return _sepolia();
    if (chainId == 42_161) return _arbitrum();
    revert UnsupportedChain(chainId);
  }

  /// @notice Hats Protocol singleton referenced by all squad sponsor clones.
  function hats() internal pure returns (address) {
    return SquadSponsorConstants.HATS_ADDRESS;
  }

  /// @notice CREATE2 deployer used by Foundry broadcast scripts (`new Contract{salt:}`).
  function create2Deployer() internal pure returns (address) {
    return CREATE2_DEFAULT_DEPLOYER;
  }

  function _mainnet() private pure returns (ChainConfig memory) {
    return ChainConfig({
      chainId: 1,
      entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
      navePirataRegistry: address(0), // set when pacto-gov mainnet registry is known
      safe4337Module: address(0), // pin from Safe docs per network
      squadSponsorFactory: address(0), // set after CREATE2 deploy
      paymaster: address(0), // set after CREATE2 deploy
      mainnetForkBlock: DEFAULT_MAINNET_FORK_BLOCK
    });
  }

  function _sepolia() private pure returns (ChainConfig memory) {
    return ChainConfig({
      chainId: 11_155_111,
      entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
      navePirataRegistry: 0xEDe67E7f75cD12F3517AaFD15D711956F3d95850, // pacto-gov / stack.json (not a deploy output)
      safe4337Module: address(0),
      squadSponsorFactory: 0x280755769367DDD108020eEF353A6dF0f8355f36, // stack.json Oct 2026 cutover
      paymaster: 0x86480317e27CF7019E966b098AF10588e021DA8f, // stack.json pactoSponsorPaymaster
      mainnetForkBlock: 0
    });
  }

  function _arbitrum() private pure returns (ChainConfig memory) {
    return ChainConfig({
      chainId: 42_161,
      entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
      navePirataRegistry: address(0),
      safe4337Module: address(0),
      squadSponsorFactory: address(0), // set after CREATE2 deploy
      paymaster: address(0), // set after CREATE2 deploy
      mainnetForkBlock: 0
    });
  }

  error UnsupportedChain(uint256 chainId);
}
