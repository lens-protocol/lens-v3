import { HardhatUserConfig } from 'hardhat/config';

import '@matterlabs/hardhat-zksync';
import '@nomicfoundation/hardhat-foundry';
import 'hardhat-contract-sizer';

const config: HardhatUserConfig = {
  defaultNetwork: 'lensSepoliaTestnet',
  networks: {
    lensSepoliaTestnet: {
      url: 'https://rpc.testnet.lens.dev',
      chainId: 37111,
      zksync: true,
      ethNetwork: 'sepolia',
      verifyURL: 'https://api-explorer-verify.staging.lens.zksync.dev/contract_verification',
    },
    dockerizedNode: {
      url: 'http://localhost:3050',
      ethNetwork: 'http://localhost:8545',
      zksync: true,
    },
    inMemoryNode: {
      url: 'http://127.0.0.1:8011',
      ethNetwork: 'localhost', // in-memory node doesn't support eth node; removing this line will cause an error
      zksync: true,
    },
    hardhat: {
      zksync: true,
    },
  },
  zksolc: {
    version: 'latest',
    settings: {
      // find all available options in the official documentation
      // https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-solc#configuration
      optimizer: {
        enabled: true, // optional. True by default
        mode: '1', // optional. 3 by default, z to optimize bytecode size
      },
    },
  },
  solidity: {
    version: '0.8.17',
  },
};

export default config;
