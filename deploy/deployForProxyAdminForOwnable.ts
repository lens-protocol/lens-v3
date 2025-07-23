import { ContractType, ContractInfo, deployLensContract, loadContractFromAddressBook, saveContractToAddressBook } from './lensUtils';

async function deploy() {
  const lensFactoryOldImpl = loadContractFromAddressBook("LensFactoryImpl");
  if (!lensFactoryOldImpl || !lensFactoryOldImpl.address || !lensFactoryOldImpl.constructorArguments) {
    throw new Error(`Previous LensFactoryImpl constructor arguments not found in address book`);
  }

  const ca = lensFactoryOldImpl.constructorArguments;

  if (ca.length !== 2) {
    throw new Error(`Old LensFactoryImpl constructor arguments malformed: length is not 2`);
  }

  if (!ca[0].accessControlFactory ||
      !ca[0].accountFactory ||
      !ca[0].appFactory ||
      !ca[0].groupFactory ||
      !ca[0].feedFactory ||
      !ca[0].graphFactory ||
      !ca[0].namespaceFactory ||
      !ca[1].accountBlockingRule ||
      !ca[1].groupGatedFeedRule ||
      !ca[1].usernameSimpleCharsetRule ||
      !ca[1].banMemberGroupRule ||
      !ca[1].addRemovePidGroupRule ||
      !ca[1].usernameReservedNamespaceRule
    ) {
    throw new Error(`Old LensFactoryImpl constructor arguments malformed`);
  }

  const accountDependentLock = loadContractFromAddressBook("AccountDependentLock");
  if (!accountDependentLock || !accountDependentLock.address || !accountDependentLock.constructorArguments) {
    throw new Error(`AccountDependentLock not found in address book`);
  }

  const accountProxyAdminForOwnable = loadContractFromAddressBook("AccountProxyAdminForOwnable");
  if (!accountProxyAdminForOwnable || !accountProxyAdminForOwnable.address || !accountProxyAdminForOwnable.constructorArguments) {
    throw new Error(`AccountProxyAdminForOwnable not found in address book`);
  }

  if (accountProxyAdminForOwnable.constructorArguments[0] !== accountDependentLock.address) {
    throw new Error(`AccountProxyAdminForOwnable Lock (${accountProxyAdminForOwnable.constructorArguments[0]}) doesn't match AccountDependentLock (${accountDependentLock.address})`);
  } else {
    console.log(`\x1b[36mUsing AccountProxyAdminForOwnable (${accountProxyAdminForOwnable.address}) with AccountDependentLock (${accountDependentLock.address}) set as the Lock\x1b[0m`);
    console.log(`\x1b[36mOwner of AccountDependentLock is: ${accountDependentLock.constructorArguments[0]}\x1b[0m`);
  }

  const accountBeacon = loadContractFromAddressBook("AccountBeacon");
  if (!accountBeacon || !accountBeacon.address) {
    throw new Error(`AccountBeacon not found in address book`);
  } else {
    console.log(`\x1b[36mUsing AccountBeacon: (${accountBeacon.address})\x1b[0m`);
  }

  //////////////// SETUP /////////////////
  const newAccountFactoryImpl: ContractInfo =
    {
      name: 'AccountFactoryImpl',
      contractName: 'AccountFactory',
      contractType: ContractType.Implementation,
      constructorArguments: [
        accountBeacon.address,
        accountProxyAdminForOwnable.address
      ],
    };

  const newLensFactoryImpl: ContractInfo =
    {
      name: 'LensFactoryImpl',
      contractName: 'LensFactory',
      contractType: ContractType.Implementation,
      constructorArguments: [
        ca[0],
        ca[1]
      ],
    };
  ////////////////////////////////////////

  console.log(`\x1b[33mDeploying new AccountFactoryImpl with the following constructor arguments:\x1b[0m`);
  console.table(newAccountFactoryImpl);

  const deployedAccountFactoryImpl = await deployLensContract(
    newAccountFactoryImpl,
    true
  );

  console.log(
    `\x1b[32m${newAccountFactoryImpl.contractName} deployed at ${deployedAccountFactoryImpl.address}\x1b[0m`
  );
  console.table(deployedAccountFactoryImpl);

  console.log(`\x1b[33mDeploying new LensFactoryImpl with the following constructor arguments:\x1b[0m`);
  console.table(newLensFactoryImpl);

  const deployedLensFactoryImpl = await deployLensContract(
    newLensFactoryImpl,
    true
  );

  console.log(
    `\x1b[32m${newLensFactoryImpl.contractName} deployed at ${deployedLensFactoryImpl.address}\x1b[0m`
  );
  console.table(deployedLensFactoryImpl);

  saveContractToAddressBook(deployedAccountFactoryImpl);
  saveContractToAddressBook(deployedLensFactoryImpl);
}

if (require.main === module) {
  deploy()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(`\x1b[31m${error}\x1b[0m`);
      process.exit(1);
    });
}

export default deploy;
