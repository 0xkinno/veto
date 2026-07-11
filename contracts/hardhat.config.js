require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { XLAYER_TESTNET_RPC, DEPLOYER_PRIVATE_KEY } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  networks: {
    xlayerTestnet: {
      url: XLAYER_TESTNET_RPC || "https://testrpc.xlayer.tech",
      chainId: 1952,
      accounts: DEPLOYER_PRIVATE_KEY ? [DEPLOYER_PRIVATE_KEY] : [],
    },
  },
};
