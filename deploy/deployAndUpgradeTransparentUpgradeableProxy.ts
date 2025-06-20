import { deployLensContract, ContractType, ContractInfo, loadContractAddressFromAddressBook, loadContractFromAddressBook, saveContractToAddressBook } from './lensUtils';
import { getWallet } from './utils';
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

  const actionHubAddress = loadContractAddressFromAddressBook('ActionHub');
  if (!actionHubAddress) {
    throw new Error('ActionHub not found in address book');
  }

  const contractToUpgradeName = 'UsernamePricePerLengthNamespaceRule';

  const contractToUpgrade: ContractInfo =
    {
      name: contractToUpgradeName + 'Impl',
      contractName: contractToUpgradeName,
      contractType: ContractType.Implementation,
      constructorArguments: [],
    };

  const transparentUpgradeableProxyContract = loadContractFromAddressBook(contractToUpgrade.contractName);
  if (!transparentUpgradeableProxyContract || !transparentUpgradeableProxyContract.address) {
    throw new Error(`${contractToUpgrade.contractName} TransparentUpgradeableProxy not found in address book`);
  }
  const transparentUpgradeableProxyAddress = transparentUpgradeableProxyContract.address;

  console.log(`${contractToUpgrade.contractName} TransparentUpgradeableProxy address: ${transparentUpgradeableProxyAddress}`);

  const proxyAdmin = await hre.upgrades.erc1967.getAdminAddress(transparentUpgradeableProxyAddress);

  if (proxyAdmin !== await getWallet(proxyOwnerPrivateKey).getAddress()) {
    throw new Error(`Proxy admin (${proxyAdmin}) in the contract is not the proxy owner derived from private key: ${await getWallet(proxyOwnerPrivateKey).getAddress()}`);
  }

  const oldImplementationInTheAddressBook = loadContractAddressFromAddressBook(contractToUpgrade.name!);
  console.log(`Old implementation in the Address Book: ${oldImplementationInTheAddressBook}`);
  const oldImplementation = await hre.upgrades.erc1967.getImplementationAddress(transparentUpgradeableProxyAddress);
  console.log(`Old implementation in the Proxy: ${oldImplementation}`);

  if (oldImplementationInTheAddressBook !== oldImplementation) {
    throw new Error(`Old implementation in the Address Book (${oldImplementationInTheAddressBook}) is not the same as the old implementation in the Proxy (${oldImplementation}).\nMaybe it was upgraded before? Or address book is outdated?`);
  }

  const deployedImplementation = await deployLensContract(
    contractToUpgrade,
    true
  );


  if (!deployedImplementation.address) {
    throw new Error(`${contractToUpgrade.contractName} new implementation not deployed`);
  } else {
    console.log(
        `${contractToUpgrade.contractName} new implementation deployed at ${deployedImplementation.address}`
    );
  }

  const proxyOwnerWallet = getWallet(proxyOwnerPrivateKey);

  const transparentUpgradeableProxyArtifact = await hre.artifacts.readArtifact('ITransparentUpgradeableProxy');
  const transparentUpgradeableProxy = new ethers.Contract(transparentUpgradeableProxyAddress, transparentUpgradeableProxyArtifact.abi, proxyOwnerWallet);

  const upgradeTx = await transparentUpgradeableProxy.upgradeTo(
    deployedImplementation.address
  );
  await upgradeTx.wait();

  const newImplementation = await hre.upgrades.erc1967.getImplementationAddress(transparentUpgradeableProxyAddress);

  if (newImplementation !== deployedImplementation.address) {
    throw new Error(`${contractToUpgrade.contractName} upgrade failed`);
  }

  console.log(`${contractToUpgrade.contractName} upgraded to ${newImplementation}`);

  saveContractToAddressBook({
    name: contractToUpgradeName,
    ...transparentUpgradeableProxyContract,
    implementation: newImplementation,
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
