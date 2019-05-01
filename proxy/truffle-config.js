/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * truffleframework.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like truffle-hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura API
 * keys are available for free at: infura.io/register
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

// const HDWalletProvider = require('truffle-hdwallet-provider');
// const infuraKey = "fj4jll3k.....";
//
// const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();
require('dotenv').config();
let hdwalletProvider = require('truffle-hdwallet-provider');
let privateKeyProvider = require('truffle-privatekey-provider');
let schainName = process.env.SCHAIN_NAME;
let mainnetRpcUrl = process.env.MAINNET_RPC_URL;
let schainRpcUrl = process.env.SCHAIN_RPC_URL;

let privateKeyForMainnet = "5802355ed674cea3bbba0935238e6327275d070779664b9afb0664a32e698ccb";
let privateKeyForSchain = "d98adda3a052bdffaf76e465063c221891eb1409d9bf4c8abb63091172b30a8c";

module.exports = {
    /**
     * Networks define how you connect to your ethereum client and let you set the
     * defaults web3 uses to send transactions. If you don't specify one truffle
     * will spin up a development blockchain for you on port 9545 when you
     * run `develop` or `test`. You can ask a truffle command to use a specific
     * network from the command line, e.g
     *
     * $ truffle test --network <network-name>
     */
  
    networks: {
      // Useful for testing. The `development` name is special - truffle uses it by default
      // if it's defined here and no other network is specified at the command line.
      // You should run a client (like ganache-cli, geth or parity) in a separate terminal
      // tab if you use this network and you must also set the `host`, `port` and `network_id`
      // options below to some value.
      //
      
      local: {
        gasPrice: 10000000000,
        host: "127.0.0.1",
        port: 8545,
        gas: 8000000,
        network_id: "*",
        from: "0xb4f9e4e7fa7e8d18cdf9d41b5ceaf2c21271bbc8"
      },
      pseudo_mainnet: {
        gasPrice: 10000000000,
        host: "127.0.0.1",
        port: 8545,
        gas: 8000000,
        network_id: "*",
        from: "0x765f224ea7cd6d84cf28bf76af025a5b9175ab07"
      },
      do: {
        host: "134.209.56.46",
        port: 1919,
        gasPrice: 10000000000,
        network_id: "*",
        from: "0x5112ce768917e907191557d7e9521c2590cdd3a0"
      },
      aws: {
        host: "13.59.228.21",
        port: 1919,
        gasPrice: 10000000000,
        network_id: "*",
      },
      aws2: {
        host: "18.218.24.50",
        port: 1919,
        gasPrice: 10000000000,
        network_id: "*",
      },
      mainnet: {
        host: "localhost",
        port: 8545,
        gasPrice: 1000000000,
        gas: 8000000,
        from: "0x0cdded6b500186dff34270101b4f3debf944977b",
        network_id: "*"
      },
      schain: {
        gasPrice: 0,
        host: "localhost",
        port: 8546,
        gas: 8000000,
        network_id: "*",
        name: schainName,
        from: "0x03676a7d813ce046cd4a4ee63480a4e22254b8ea",
        skipDryRun: true
      }
  
      // Another network with more advanced options...
      // advanced: {
        // port: 8777,             // Custom port
        // network_id: 1342,       // Custom network
        // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
        // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
        // from: <address>,        // Account to send txs from (default: accounts[0])
        // websockets: true        // Enable EventEmitter interface for web3 (default: false)
      // },
  
      // Useful for deploying to a public network.
      // NB: It's important to wrap the provider as a function.
      // ropsten: {
        // provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/${infuraKey}`),
        // network_id: 3,       // Ropsten's id
        // gas: 5500000,        // Ropsten has a lower block limit than mainnet
        // confirmations: 2,    // # of confs to wait between deployments. (default: 0)
        // timeoutBlocks: 200,  // # of blocks before a deployment times out  (minimum/default: 50)
        // skipDryRun: true     // Skip dry run before migrations? (default: false for public nets )
      // },
  
      // Useful for private networks
      // private: {
        // provider: () => new HDWalletProvider(mnemonic, `https://network.io`),
        // network_id: 2111,   // This network is yours, in the cloud.
        // production: true    // Treats this network as if it was a public net. (default: false)
      // }
    },
  
    // Set default mocha options here, use special reporters etc.
    mocha: {
      // timeout: 100000
    },
  
    // Configure your compilers
    compilers: {
      solc: {
        version: "0.5.7",    // Fetch exact version from solc-bin (default: truffle's version)
        /*docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
        settings: {          // See the solidity docs for advice about optimization and evmVersion
         optimizer: {
           enabled: false,
           runs: 200
         },
         evmVersion: "byzantium"
        }*/
      }
    }
  }
  