import { ContractType, ContractInfo, loadContractAddressFromAddressBook } from './lensUtils';
import { deployContract } from './utils';

async function deploy() {
  const contractToDeploy: ContractInfo =
    // Factories
    {
      name: 'AccessControlFactory',
      contractName: 'AccessControlFactory',
      contractType: ContractType.Factory,
      constructorArguments: [loadContractAddressFromAddressBook('AccessControlLock')],
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
