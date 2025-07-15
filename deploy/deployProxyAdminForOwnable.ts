import {
  ContractType,
  ContractInfo,
  deployLensContract,
  loadAddressBook,
  promptForConfirmation,
  saveContractToAddressBook,
} from './lensUtils';

async function deploy() {
  const addressBook = loadAddressBook();
  let dependentLock = addressBook['AccountDependentLock']?.address;

  if (!dependentLock) {
    console.log('\x1b[33mDependentLock address not found in the address book\x1b[0m');

    // Read PROXY_ADMIN_LOCK_OWNER from .env
    const proxyAdminLockOwner = process.env.PROXY_ADMIN_LOCK_OWNER;
    if (!proxyAdminLockOwner) {
      throw new Error('\x1b[31mPROXY_ADMIN_LOCK_OWNER not found in .env\x1b[0m');
    } else {
      console.log(`\x1b[36mUsing PROXY_ADMIN_LOCK_OWNER: ${proxyAdminLockOwner}\x1b[0m`);
    }

    const confirm = await promptForConfirmation(
      'Do you want to deploy DeploymentLock? (Y/y to confirm): '
    );
    if (!confirm) {
      console.log('\x1b[33mAborted by user.\x1b[0m');
      process.exit(0);
    }


    const contractToDeploy: ContractInfo = {
      name: 'AccountDependentLock',
      contractName: 'DependentLock',
      contractType: ContractType.Aux,
      constructorArguments: [
        proxyAdminLockOwner,
        true, // locked
      ],
    };
    const deployedImplementation = await deployLensContract(contractToDeploy, true);

    console.log(`\x1b[32m${contractToDeploy.name} deployed at ${deployedImplementation.address}\x1b[0m`);
    console.table(deployedImplementation);

    saveContractToAddressBook(deployedImplementation);

    dependentLock = deployedImplementation.address;
  } else {
    console.log(
      `\x1b[36mDependentLock address being used for new action implementations: ${dependentLock}\x1b[0m\n\n`
    );
  }

  const proxyAdminForOwnable = addressBook['AccountProxyAdminForOwnable']?.address;

  if (proxyAdminForOwnable) {
    console.log('\x1b[33mProxyAdminForOwnable is already present in the address book\x1b[0m');

    const confirm = await promptForConfirmation(
      'Do you want to redeploy ProxyAdminForOwnable? (Y/y to confirm): '
    );
    if (!confirm) {
      console.log('\x1b[33mAborted by user.\x1b[0m');
      process.exit(0);
    }
  }

  const contractToDeploy: ContractInfo = {
    name: 'AccountProxyAdminForOwnable',
    contractName: 'ProxyAdminForOwnable',
    contractType: ContractType.Aux,
    constructorArguments: [dependentLock],
  };

  const deployedImplementation = await deployLensContract(contractToDeploy, true);

  console.log(`\x1b[32m${contractToDeploy.name} deployed at ${deployedImplementation.address}\x1b[0m`);
  console.table(deployedImplementation);

  saveContractToAddressBook(deployedImplementation);
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
