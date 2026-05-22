// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {SquadSponsorConstants} from 'contracts/utils/constants/SquadSponsorConstants.sol';

/// @dev Hats Protocol v1 — same as `SquadSponsorConstants.HATS_ADDRESS`; fork presence check for integration tests.
address constant HATS_PROTOCOL_V1 = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;

/// @dev Default block pin for `vm.createSelectFork` when `MAINNET_RPC` is set (stable Hats singleton).
uint256 constant DEFAULT_MAINNET_FORK_BLOCK = 22_900_000;

/// @notice Public chain constants and deployed contract addresses.
/// @dev Private values (RPC URLs, API keys, deployer keystore names) live in `.env` only.
/// @dev Deploy (`script/Deploy.sol`) CREATE2-deploys `SquadSponsorFactory(entryPoint)`; paymaster is created in the factory constructor.
/// Hats is not a constructor arg — it is baked into sponsor bytecode via `SquadSponsorConstants.HATS_ADDRESS`.
library Constants {
  /**
   * @notice Chain-level deployment configuration.
   * @param chainId The supported network's chain ID.
   * @param entryPoint ERC-4337 EntryPoint v0.7 wired into `PactoSponsorPaymaster`.
   * @param navePirataRegistry Pacto-gov registry for hat eligibility lookups (integration / app consumption).
   * @param safe4337Module Safe 4337 module address for Path A UserOps (integration / app consumption).
   * @param squadSponsorFactory CREATE2-deployed `SquadSponsorFactory` — set after deploy.
   * @param paymaster CREATE2-deployed `PactoSponsorPaymaster` — set after deploy.
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
      navePirataRegistry: address(0),
      safe4337Module: address(0),
      squadSponsorFactory: address(0), // set after CREATE2 deploy
      paymaster: address(0), // set after CREATE2 deploy
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
