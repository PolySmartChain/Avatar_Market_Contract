import "@nomiclabs/hardhat-waffle"
import 'hardhat-deploy'
import "solidity-coverage"
import "@openzeppelin/hardhat-upgrades"

import dotenv from 'dotenv';
dotenv.config();

export default {
  solidity: {
    compilers: [
      {
         version: "0.8.11",
      }
    ],
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: 'istanbul',
    },
  },
  defaultNetwork: "Mumbai",
  networks: {
    hardhat: {
        gas: 120000000,
        blockGasLimit: 120000000,
        allowUnlimitedContractSize: true,
        timeout: 1800000,
        initialBaseFeePerGas: 0
      },
    Goerli: {
      url: 'https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
      accounts: [process.env.PRIVATE_KEY]
    },
    Mumbai: {
      url: "https://seed0.polysmartchain.com/",
       accounts: [process.env.PRIVATE_KEY]
    },
    Localhost: {
      url: "http://192.168.8.40:9111/",
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
