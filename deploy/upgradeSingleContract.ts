import { ContractType, ContractInfo, loadContractAddressFromAddressBook, saveContractToAddressBook } from './lensUtils';
import { deployContract, getWallet } from './utils';
import * as hre from 'hardhat';
import { ethers } from 'ethers';

async function deploy() {
  const proxyOwnerPrivateKey = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!proxyOwnerPrivateKey) {
    throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
  }

  const proxyOwnerBalance = await getWallet(proxyOwnerPrivateKey).getBalance();
  if (proxyOwnerBalance < ethers.parseEther('0.01')) {
    throw new Error('Proxy owner balance is less than 0.01 ETH');
  }

  console.log(`Using proxy owner private key with address: ${await getWallet(proxyOwnerPrivateKey).getAddress()}`);
  console.log(`Proxy owner balance: ${ethers.formatEther(proxyOwnerBalance)}`);

  const contractToUpgrade: ContractInfo =
    // Factories
    {
      name: 'AccessControlFactoryImpl',
      contractName: 'AccessControlFactory',
      contractType: ContractType.Factory,
      constructorArguments: [loadContractAddressFromAddressBook('AccessControlLock')],
    };

  if (contractToUpgrade.constructorArguments === undefined) {
    throw new Error('AccessControlLock not found in address book');
  }

  const transparentUpgradeableProxyAddress = loadContractAddressFromAddressBook(contractToUpgrade.contractName);
  if (!transparentUpgradeableProxyAddress) {
    throw new Error(`${contractToUpgrade.contractName} not found in address book`);
  }

  console.log(`${contractToUpgrade.contractName} transparent upgradeable proxy address: ${transparentUpgradeableProxyAddress}`);

  // const proxyAdmin = await getProvider().getStorage(transparentUpgradeableProxyAddress, proxyAdminSlot);
  const proxyAdmin = await hre.upgrades.erc1967.getAdminAddress(transparentUpgradeableProxyAddress);

  if (proxyAdmin !== await getWallet(proxyOwnerPrivateKey).getAddress()) {
    throw new Error(`Proxy admin (${proxyAdmin}) in the contract is not the proxy owner derived from private key: ${await getWallet(proxyOwnerPrivateKey).getAddress()}`);
  }

  const oldImplementation = await hre.upgrades.erc1967.getImplementationAddress(transparentUpgradeableProxyAddress);
  console.log(`Old implementation in the Proxy: ${oldImplementation}`);

  const deployedImplementation = await deployContract(
    contractToUpgrade.contractName,
    contractToUpgrade.constructorArguments
  );

  console.log(
      `${contractToUpgrade.contractName} implementation deployed at ${await deployedImplementation.getAddress()}`
  );

  const proxyOwnerWallet = getWallet(proxyOwnerPrivateKey);

  const transparentUpgradeableProxyArtifact = await hre.artifacts.readArtifact('ITransparentUpgradeableProxy');
  const transparentUpgradeableProxy = new ethers.Contract(transparentUpgradeableProxyAddress, transparentUpgradeableProxyArtifact.abi, proxyOwnerWallet);

  const upgradeTx = await transparentUpgradeableProxy.upgradeTo(
    await deployedImplementation.getAddress()
  );
  await upgradeTx.wait();

  const newImplementation = await hre.upgrades.erc1967.getImplementationAddress(transparentUpgradeableProxyAddress);

  if (newImplementation !== await deployedImplementation.getAddress()) {
    throw new Error(`${contractToUpgrade.contractName} upgrade failed`);
  }

  console.log(`${contractToUpgrade.contractName} upgraded to ${newImplementation}`);

  saveContractToAddressBook({
    ...contractToUpgrade,
    address: newImplementation,
  });
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
