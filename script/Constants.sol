// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Public chain constants and deployed contract addresses.
/// @dev Private values (RPC URLs, API keys, deployer keystore names) live in `.env` only.
library Constants {
  struct ChainConfig {
    uint256 chainId;
    address entryPoint;
    address hats;
    address navePirataRegistry;
    address safe4337Module;
    address squadSponsorFactory;
    address paymaster;
    uint256 mainnetForkBlock;
  }

  function getConfig(uint256 chainId) internal pure returns (ChainConfig memory config) {
    if (chainId == 1) return _mainnet();
    if (chainId == 11_155_111) return _sepolia();
    if (chainId == 42_161) return _arbitrum();
    revert UnsupportedChain(chainId);
  }

  function _mainnet() private pure returns (ChainConfig memory) {
    return ChainConfig({
      chainId: 1,
      entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
      hats: 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137,
      navePirataRegistry: address(0), // set when pacto-gov mainnet registry is known
      safe4337Module: address(0), // pin from Safe docs per network
      squadSponsorFactory: address(0), // set after deploy
      paymaster: address(0),
      mainnetForkBlock: 21_500_000
    });
  }

  function _sepolia() private pure returns (ChainConfig memory) {
    return ChainConfig({
      chainId: 11_155_111,
      entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
      hats: 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137,
      navePirataRegistry: address(0),
      safe4337Module: address(0),
      squadSponsorFactory: address(0),
      paymaster: address(0),
      mainnetForkBlock: 0
    });
  }

  function _arbitrum() private pure returns (ChainConfig memory) {
    return ChainConfig({
      chainId: 42_161,
      entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
      hats: 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137,
      navePirataRegistry: address(0),
      safe4337Module: address(0),
      squadSponsorFactory: address(0),
      paymaster: address(0),
      mainnetForkBlock: 0
    });
  }

  error UnsupportedChain(uint256 chainId);
}
