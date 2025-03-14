import { ContractType, ContractInfo, loadContractAddressFromAddressBook } from './lensUtils';
import { deployContract } from './utils';

async function deploy() {
  const contractToDeploy: ContractInfo =
    // Factories
    {
      name: 'WhitelistedMulticallImpl',
      contractName: 'WhitelistedMulticall',
      contractType: ContractType.Factory,
      constructorArguments: [],
    };

  const deployedImplementation = await deployContract(
    contractToDeploy.contractName,
    contractToDeploy.constructorArguments
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
