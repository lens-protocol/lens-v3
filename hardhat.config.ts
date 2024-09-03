import { HardhatUserConfig } from "hardhat/config";

import "@matterlabs/hardhat-zksync";
import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
  defaultNetwork: "lensSepoliaTestnet",
  networks: {
    lensSepoliaTestnet: {
      url: "https://sepolia.rpc.lens.dev",
      chainId: 37111,
      zksync: true,
      ethNetwork: "sepolia",
      verifyURL:
        "https://api-explorer-verify.staging.lens.zksync.dev/contract_verification",
    },
    hardhat: {
      zksync: true,
    },
  },
  zksolc: {
    version: "latest",
    settings: {
      // find all available options in the official documentation
      // https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-solc#configuration
    },
  },
  solidity: {
    version: "0.8.17",
  },
};

export default config;
