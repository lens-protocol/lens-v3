import {
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
  saveContractToAddressBook,
} from '../../lensUtils';
import { deployContract, getWallet } from '../../utils';
import * as hre from 'hardhat';
import { ethers, Wallet } from 'ethers';

async function deploy() {
  const proxyOwnerPrivateKey = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!proxyOwnerPrivateKey) {
    throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
  }

  const proxyOwnerWallet = await getWallet(proxyOwnerPrivateKey);
  const proxyOwnerAddress = await proxyOwnerWallet.getAddress();

  const proxyOwnerBalance = await proxyOwnerWallet.getBalance();
  if (proxyOwnerBalance < ethers.parseEther('0.01')) {
    throw new Error('Proxy owner balance is less than 0.01 ETH');
  }

  console.log(`Using proxy owner private key with address: ${proxyOwnerAddress}`);
  console.log(`Proxy owner balance: ${ethers.formatEther(proxyOwnerBalance)}`);

  await transparentProxyUpgrade('AccessControlFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('AccountFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('AppFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('FeedFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('GraphFactory', proxyOwnerWallet, proxyOwnerAddress);
  // GroupFactory was already deployed as normal, non-migration implementation
  // await transparentProxyUpgrade('GroupFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('NamespaceFactory', proxyOwnerWallet, proxyOwnerAddress);
  await transparentProxyUpgrade('LensFactory', proxyOwnerWallet, proxyOwnerAddress);
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

  console.log(`${contractToUpgrade.contractName} upgraded to ${upgradedImplementation}`);
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
