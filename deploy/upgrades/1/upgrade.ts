import {
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
} from '../../lensUtils';
import { getWallet, getProvider } from '../../utils';
import * as hre from 'hardhat';
import { ethers, Wallet } from 'ethers';

async function deploy() {
  ////////////////////////
  ///// PROXY OWNER /////
  ////////////////////////

  const proxyOwnerPrivateKey = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!proxyOwnerPrivateKey) {
    throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
  }

  const proxyOwnerWallet = await getWallet(proxyOwnerPrivateKey);
  const proxyOwnerAddress = await proxyOwnerWallet.getAddress();

  // const proxyOwnerBalance = await proxyOwnerWallet.getBalance();
  // if (proxyOwnerBalance < ethers.parseEther('0.01')) {
  //   throw new Error('Proxy owner balance is less than 0.01 ETH');
  // }

  console.log(`Using proxy owner private key with address: ${proxyOwnerAddress}`);
  // console.log(`Proxy owner balance: ${ethers.formatEther(proxyOwnerBalance)}`);

  ////////////////////////
  ///// BEACON OWNER /////
  ////////////////////////

  const beaconOwnerPrivateKey = process.env.BEACON_OWNER_PRIVATE_KEY;
  if (!beaconOwnerPrivateKey) {
    throw new Error('BEACON_OWNER_PRIVATE_KEY not found in environment variables');
  }

  const beaconOwnerWallet = await getWallet(beaconOwnerPrivateKey);
  const beaconOwnerAddress = await beaconOwnerWallet.getAddress();

  // const beaconOwnerBalance = await beaconOwnerWallet.getBalance();
  // if (beaconOwnerBalance < ethers.parseEther('0.01')) {
    // throw new Error('Beacon owner balance is less than 0.01 ETH');
  // }

  ///////////////////////////// TRANSPARENT UPGRADEABLE PROXY UPGRADES ///////////////////////////////////

  await transparentProxyUpgrade('AccessControlFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('AccountFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('AppFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('FeedFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('GraphFactory', proxyOwnerWallet, proxyOwnerAddress);
  // GroupFactory was already deployed as normal, non-migration implementation
  await transparentProxyUpgrade('GroupFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('NamespaceFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('LensFactory', proxyOwnerWallet, proxyOwnerAddress);

  //////////////////////////////////////// BEACONS UPGRADES //////////////////////////////////////////////

  await beaconUpgrade('Feed', beaconOwnerWallet, beaconOwnerAddress);
  await beaconUpgrade('Namespace', beaconOwnerWallet, beaconOwnerAddress);
  await beaconUpgrade('Graph', beaconOwnerWallet, beaconOwnerAddress);
  await beaconUpgrade('Account', beaconOwnerWallet, beaconOwnerAddress);
  await beaconUpgrade('App', beaconOwnerWallet, beaconOwnerAddress);
}

async function beaconUpgrade(
  contractToUpgradeName: string,
  beaconOwnerWallet: Wallet,
  beaconOwnerAddress: string
) {
  const beaconContractName = contractToUpgradeName + 'Beacon';
  const beaconContractAddress = loadContractAddressFromAddressBook(beaconContractName);
  if (!beaconContractAddress) {
    throw new Error(`${beaconContractName} not found in address book`);
  }

  console.log(`Upgrading ${beaconContractName} from ${beaconContractAddress}`);

  const beaconContractArtifact = await hre.artifacts.readArtifact("Beacon");

  const beaconContract = new ethers.Contract(
    beaconContractAddress,
    beaconContractArtifact.abi,
    beaconOwnerWallet
  );

  // Owner
  const beaconContractOwner = await beaconContract.owner();
  console.log(`Beacon contract owner: ${beaconContractOwner}`);

  if (beaconContractOwner !== beaconOwnerAddress) {
    throw new Error(`Beacon contract owner ${beaconContractOwner} is not the beacon owner derived from private key: ${beaconOwnerAddress}`);
  }

  const beaconContractImplementationBefore = await beaconContract.implementation();
  console.log(`Beacon contract old implementation: ${beaconContractImplementationBefore}`);

  // As there is no getter, we read Default Version Storage Slot 1
  const beaconDefaultVersionBytes = await getProvider().getStorage(beaconContractAddress, 1);
  const beaconDefaultVersion = ethers.toNumber(beaconDefaultVersionBytes);
  console.log(`Beacon contract default version: ${beaconDefaultVersion}`);
  const beaconNewVersion = beaconDefaultVersion + 1;
  console.log(`Beacon contract new version: ${beaconNewVersion}`);

  // Set new implementation
  const beaconNewContractImplementation = loadContractAddressFromAddressBook(contractToUpgradeName + 'Impl');
  if (!beaconNewContractImplementation) {
    throw new Error(`${contractToUpgradeName} implementation not found in address book`);
  }

  console.log(`Setting new implementation ${beaconNewContractImplementation} for version ${beaconNewVersion}`);

  const beaconUpgradeTx = await beaconContract.setImplementationForVersion(beaconNewVersion, beaconNewContractImplementation);
  await beaconUpgradeTx.wait();

  const beaconSetDefaultVersionTx = await beaconContract.setDefaultVersion(beaconNewVersion);
  await beaconSetDefaultVersionTx.wait();

  const beaconDefaultVersionAfterBytes = await getProvider().getStorage(beaconContractAddress, 1);
  const beaconDefaultVersionAfter = ethers.toNumber(beaconDefaultVersionAfterBytes);

  const beaconContractImplementationAfter = await beaconContract.implementation();

  if (beaconContractImplementationAfter !== beaconNewContractImplementation) {
    throw new Error(`Beacon contract implementation after upgrade ${beaconContractImplementationAfter} is not the new implementation ${beaconNewContractImplementation}`  );
  }
  console.log(`Beacon contract upgraded to implementation ${beaconNewContractImplementation}`);

  if (beaconDefaultVersionAfter !== beaconNewVersion) {
    throw new Error(`Beacon contract default version after upgrade ${beaconDefaultVersionAfter} is not the new version ${beaconNewVersion}`);
  }

  console.log(`Beacon contract DefaultVersion is set to ${beaconNewVersion}`);

  console.log(`\x1b[32mBeacon for ${contractToUpgradeName} upgraded to version ${beaconNewVersion} with implementation ${beaconNewContractImplementation}\x1b[0m`);
}

async function transparentProxyUpgrade(
  contractToUpgradeName: string,
  proxyOwnerWallet: Wallet,
  proxyOwnerAddress: string
) {
  const contractToUpgrade: ContractInfo =
    {
      name: contractToUpgradeName + 'Impl',
      contractName: contractToUpgradeName,
      contractType: ContractType.Implementation,
    };

  const transparentUpgradeableProxyAddress = loadContractAddressFromAddressBook(
    contractToUpgrade.contractName
  );
  if (!transparentUpgradeableProxyAddress) {
    throw new Error(`${contractToUpgrade.contractName} not found in address book`);
  }

  console.log(
    `${contractToUpgrade.contractName} transparent upgradeable proxy address: ${transparentUpgradeableProxyAddress}`
  );

  const proxyAdmin = await hre.upgrades.erc1967.getAdminAddress(transparentUpgradeableProxyAddress);

  if (proxyAdmin !== proxyOwnerAddress) {
    throw new Error(
      `Proxy admin (${proxyAdmin}) in the contract is not the proxy owner derived from private key: ${proxyOwnerAddress}`
    );
  }

  const beforeImplementation = await hre.upgrades.erc1967.getImplementationAddress(
    transparentUpgradeableProxyAddress
  );
  console.log(`Old implementation in the Proxy: ${beforeImplementation}`);

  const newImplementation = loadContractAddressFromAddressBook(contractToUpgrade.name!);
  if (!newImplementation) {
    throw new Error(`${contractToUpgrade.contractName} implementation not found in address book`);
  }

  console.log(`New ${contractToUpgrade.contractName} implementation to upgrade to: ${newImplementation}`);

  const transparentUpgradeableProxyArtifact = await hre.artifacts.readArtifact(
    'ITransparentUpgradeableProxy'
  );
  const transparentUpgradeableProxy = new ethers.Contract(
    transparentUpgradeableProxyAddress,
    transparentUpgradeableProxyArtifact.abi,
    proxyOwnerWallet
  );

  const upgradeTx = await transparentUpgradeableProxy.upgradeTo(newImplementation);
  await upgradeTx.wait();

  const upgradedImplementation = await hre.upgrades.erc1967.getImplementationAddress(
    transparentUpgradeableProxyAddress
  );

  if (upgradedImplementation !== newImplementation) {
    throw new Error(`${contractToUpgrade.contractName} upgrade failed`);
  }

  console.log(`\x1b[32m${contractToUpgrade.contractName} upgraded to ${upgradedImplementation}\x1b[0m`);
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
