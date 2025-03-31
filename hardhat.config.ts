import { HardhatUserConfig } from 'hardhat/config';

import '@matterlabs/hardhat-zksync';
import '@openzeppelin/hardhat-upgrades';
import '@nomicfoundation/hardhat-foundry';
import 'hardhat-contract-sizer';
import 'hardhat-ignore-warnings';

const config: HardhatUserConfig = {
  defaultNetwork: 'lensSepoliaTestnet',
  networks: {
    lensSepoliaTestnet: {
      url: 'https://rpc.testnet.lens.dev',
      chainId: 37111,
      zksync: true,
      ethNetwork: 'sepolia',
      verifyURL: 'https://api-explorer-verify.staging.lens.zksync.dev/contract_verification',
      enableVerifyURL: true,
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
    zkstackMigrationNode: {
      url: 'http://localhost:3050',
      chainId: 271,
      zksync: true,
      ethNetwork: 'sepolia',
    },
    lensMainnet: {
      chainId: 232,
      url: "https://api.lens.matterhosted.dev/",
      ethNetwork: `https://eth-sepolia.g.alchemy.com/v2/${process.env.SEPOLIA_ALCHEMY_API_KEY}`, // dont think you need this
      zksync: true,
      verifyURL:
        "https://api-explorer-verify.lens.matterhosted.dev/contract_verification",
    },
    hardhat: {
      zksync: true,
    },
  },
  zksolc: {
    version: '1.5.12',
    settings: {
      evmVersion: 'paris',
      // find all available options in the official documentation
      // https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-solc#configuration
      optimizer: {
        enabled: true, // optional. True by default
        mode: '1', // optional. 3 by default, z to optimize bytecode size
      },
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        bytecodeHash: 'none',
      },
      codegen: 'yul'
    },
  },
  solidity: {
    version: '0.8.28',
  },
};

export default config;
