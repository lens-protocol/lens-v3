import { ContractType, ContractInfo } from '../../lensUtils';
import { deployContract, getWallet, LOCAL_RICH_WALLETS } from '../../utils';
import { ethers } from 'ethers';
import * as hre from 'hardhat';
async function deploy() {
  const DEPLOYING_FR = Boolean(process.env.DEPLOY_FR);

  const multicallDeployerPrivateKey = process.env.MULTICALL_DEPLOYER_PRIVATE_KEY;
  if (!multicallDeployerPrivateKey) {
    throw new Error('MULTICALL_DEPLOYER_PRIVATE_KEY not found in environment variables');
  }

  const factoriesProxyOwner = process.env.FACTORIES_PROXY_OWNER;
  if (!factoriesProxyOwner) {
    throw new Error('FACTORIES_PROXY_OWNER not found in environment variables');
  }

  const multicallDeployerWallet = getWallet(multicallDeployerPrivateKey);

  if (!DEPLOYING_FR) {
    const richWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    await richWallet.sendTransaction({
      to: multicallDeployerWallet.address,
      value: ethers.parseEther("1.0")
    });
  }

  const nonce = await multicallDeployerWallet.getNonce();

  console.log(`Multicall deployer nonce: ${nonce}`);
  if (nonce !== 0) {
    throw new Error('Multicall deployer nonce is not 0 - ABORTING');
  }


  const whitelistedMulticallImpl: ContractInfo =
  {
    name: 'WhitelistedMulticallImpl',
    contractName: 'WhitelistedMulticall',
    contractType: ContractType.Implementation,
    constructorArguments: [],
  };

  const deployedImplementation = await deployContract(
    whitelistedMulticallImpl.contractName,
    whitelistedMulticallImpl.constructorArguments,
    {
      wallet: multicallDeployerWallet,
    }
  );

  console.log(
    `${whitelistedMulticallImpl.contractName} deployed at ${await deployedImplementation.getAddress()}`
  );

  // Deploy TransparentUpgradeableProxy first and then upgrade it to implementation.
  // deploy the proxy after with the implementation address inside

  const proxyInfo: ContractInfo = {
    name: whitelistedMulticallImpl.contractName,
    contractName: 'TransparentUpgradeableProxy',
    contractType: ContractType.Aux,
    constructorArguments: [await deployedImplementation.getAddress(), factoriesProxyOwner, '0x'],
  };

  const deployedProxy = await deployContract(proxyInfo.contractName, proxyInfo.constructorArguments, {
    wallet: multicallDeployerWallet,
  });

  console.log(
    `${proxyInfo.name} (proxy) deployed at ${await deployedProxy.getAddress()}`
  );

  const proxyAdmin = await hre.upgrades.erc1967.getAdminAddress(await deployedProxy.getAddress());
  console.log(`Proxy admin: ${proxyAdmin}`);

  const implementation = await hre.upgrades.erc1967.getImplementationAddress(
    await deployedProxy.getAddress()
  );
  console.log(`Implementation in the Proxy: ${implementation}`);

}



if (require.main === module) {
  deploy()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export default deploy;
