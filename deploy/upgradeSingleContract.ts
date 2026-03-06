// SPDX-License-Identifier: GPL-3.0-only

import { ContractType, ContractInfo, loadContractAddressFromAddressBook, saveContractToAddressBook } from './lensUtils';
import { deployContract, getWallet } from './utils';
import * as hre from 'hardhat';
import { ethers } from 'ethers';

async function deploy() {
  //////////////// SETUP /////////////////
  const contractToUpgrade = 'LensFactory';
  ////////////////////////////////////////

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

  const transparentUpgradeableProxyAddress = loadContractAddressFromAddressBook(contractToUpgrade);
  if (!transparentUpgradeableProxyAddress) {
    throw new Error(`${contractToUpgrade} not found in address book`);
  }

  console.log(`${contractToUpgrade} transparent upgradeable proxy address: ${transparentUpgradeableProxyAddress}`);

  // const proxyAdmin = await getProvider().getStorage(transparentUpgradeableProxyAddress, proxyAdminSlot);
  const proxyAdmin = await hre.upgrades.erc1967.getAdminAddress(transparentUpgradeableProxyAddress);

  if (proxyAdmin !== await getWallet(proxyOwnerPrivateKey).getAddress()) {
    throw new Error(`Proxy admin (${proxyAdmin}) in the contract is not the proxy owner derived from private key: ${await getWallet(proxyOwnerPrivateKey).getAddress()}`);
  }

  const oldImplementation = await hre.upgrades.erc1967.getImplementationAddress(transparentUpgradeableProxyAddress);
  console.log(`Old implementation in the Proxy: ${oldImplementation}`);

  const newImplementation = loadContractAddressFromAddressBook(contractToUpgrade + 'Impl');
  if (!newImplementation) {
    throw new Error(`${contractToUpgrade} implementation not found in address book`);
  }

  console.log(
      `${contractToUpgrade} implementation deployed at ${newImplementation}`
  );

  const proxyOwnerWallet = getWallet(proxyOwnerPrivateKey);

  const transparentUpgradeableProxyArtifact = await hre.artifacts.readArtifact('ITransparentUpgradeableProxy');
  const transparentUpgradeableProxy = new ethers.Contract(transparentUpgradeableProxyAddress, transparentUpgradeableProxyArtifact.abi, proxyOwnerWallet);

  const upgradeTx = await transparentUpgradeableProxy.upgradeTo(
    newImplementation
  );
  await upgradeTx.wait();

  const newImplementationOnProxy = await hre.upgrades.erc1967.getImplementationAddress(transparentUpgradeableProxyAddress);

  if (newImplementation !== newImplementationOnProxy) {
    throw new Error(`${contractToUpgrade} upgrade failed`);
  }

  console.log(`\x1b[32m${contractToUpgrade} upgraded to ${newImplementation}\x1b[0m`);
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
