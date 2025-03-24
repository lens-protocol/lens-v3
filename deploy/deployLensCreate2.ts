import { Deployer } from '@matterlabs/hardhat-zksync';
import { ContractType, ContractInfo, saveContractToAddressBook } from './lensUtils';
import { deployContract, getWallet, LOCAL_RICH_WALLETS } from './utils';
import { ethers } from 'ethers';
import * as hre from 'hardhat';

async function deploy() {
  const DEPLOYING_FR = Boolean(process.env.DEPLOY_FR);

  const lensCreate2DeployerPrivateKey = process.env.LENS_CREATE2_DEPLOYER_PRIVATE_KEY;
  if (!lensCreate2DeployerPrivateKey) {
    throw new Error('LENS_CREATE2_DEPLOYER_PRIVATE_KEY not found in environment variables');
  }

  const lensCreate2DeployerWallet = getWallet(lensCreate2DeployerPrivateKey);

  if (!DEPLOYING_FR) {
    const richWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    await richWallet.sendTransaction({
      to: lensCreate2DeployerWallet.address,
      value: ethers.parseEther('1.0'),
    });
  }

  const nonce = await lensCreate2DeployerWallet.getNonce();

  console.log(`LensCreate2 deployer nonce: ${nonce}`);
  if (nonce !== 0) {
    throw new Error('LensCreate2 deployer nonce is not 0 - ABORTING');
  }

  const lensCreate2Info: ContractInfo = {
    name: 'LensCreate2',
    contractName: 'LensCreate2',
    contractType: ContractType.Aux,
    constructorArguments: [],
  };

  const deployer = new Deployer(hre, lensCreate2DeployerWallet);
  const artifact = await deployer.loadArtifact('TransparentUpgradeableProxy').catch((error) => {
    if (
      error?.message?.includes(`Artifact for contract "TransparentUpgradeableProxy" not found.`)
    ) {
      console.error(error.message);
      throw `⛔️ Please make sure you have compiled your contracts or specified the correct contract name!`;
    } else {
      throw error;
    }
  });

  console.log('Artifact Bytecode:\n', artifact.bytecode);

  const lensCreate2Deployed = await deployContract(
    lensCreate2Info.contractName,
    lensCreate2Info.constructorArguments,
    {
      wallet: lensCreate2DeployerWallet,
    }
  );

  lensCreate2Info.address = await lensCreate2Deployed.getAddress();

  saveContractToAddressBook(lensCreate2Info);

  console.log(`${lensCreate2Info.contractName} deployed at ${lensCreate2Info.address}`);
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
