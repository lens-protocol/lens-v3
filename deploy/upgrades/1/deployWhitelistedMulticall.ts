import { ContractType, ContractInfo } from '../../lensUtils';
import { deployContract, getWallet, LOCAL_RICH_WALLETS } from '../../utils';
import { ethers } from 'ethers';

async function deploy() {
  const DEPLOYING_FR = Boolean(process.env.DEPLOY_FR);

  const multicallDeployerPrivateKey = process.env.MULTICALL_DEPLOYER_PRIVATE_KEY;
  if (!multicallDeployerPrivateKey) {
    throw new Error('MULTICALL_DEPLOYER_PRIVATE_KEY not found in environment variables');
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

  const contractToDeploy: ContractInfo =
    {
      name: 'WhitelistedMulticall',
      contractName: 'WhitelistedMulticall',
      contractType: ContractType.Aux,
      constructorArguments: [],
    };

  const deployedImplementation = await deployContract(
    contractToDeploy.contractName,
    contractToDeploy.constructorArguments,
    {
      wallet: multicallDeployerWallet,
    }
  );

  console.log(
    `${contractToDeploy.contractName} deployed at ${await deployedImplementation.getAddress()}`
  );
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
