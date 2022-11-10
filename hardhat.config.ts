import "@nomiclabs/hardhat-waffle"
import 'hardhat-deploy'
import "solidity-coverage"

export default {
  solidity: {
    version: '0.8.1',
    settings: {
      optimizer: { enabled: true, runs: 200 },
      evmVersion: 'istanbul',
    },
  },
  networks: {
    hardhat: {
        initialBaseFeePerGas: 0
      },
    Goerli: {
      url: 'https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
      accounts: [process.env.PRIVATE_KEY]
    },
    PSC: {
      url: 'https://seed0.polysmartchain.com',
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
