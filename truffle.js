require("dotenv").config();
const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    // bsc testnet 
    bscTestnet: {
      provider: () => new HDWalletProvider(process.env.pk, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      confirmations: 3,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    nova: {
      provider: () => new HDWalletProvider(process.env.pk, `https://nova.arbitrum.io/rpc`),
      network_id: 42170,
      confirmations: 3,
      timeoutBlocks: 200,
      skipDryRun: true
    },
  },
  
  compilers: {
    solc: {
      version: "^0.8.4", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
       optimizer: {
         enabled: true,
         runs: 200
       },
      //  evmVersion: "byzantium"
      }
    },
  },
  plugins: ['truffle-plugin-verify'],
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
    testnet_bscscan: process.env.testnet_bscscan_API_KEY,
  },

};
