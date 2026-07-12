require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { XLAYER_RPC, XLAYER_TESTNET_RPC, DEPLOYER_PRIVATE_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    // X Layer MAINNET (chain 196) — the deploy that counts.
    xlayer: {
      url: XLAYER_RPC || "https://rpc.xlayer.tech",
      chainId: 196,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
    },
    // X Layer testnet (chain 195/1952) — kept for reference.
    xlayerTestnet: {
      url: XLAYER_TESTNET_RPC || "https://testrpc.xlayer.tech",
      chainId: 195,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
    },
  },
};
