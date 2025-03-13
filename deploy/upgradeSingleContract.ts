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
      name: 'LensFactoryImpl',
      address: '0x37a998C7A641A9440B96b2eA43Ef8c0ED7d19435',
      contractName: 'LensFactory',
      contractType: ContractType.Factory,
      constructorArguments: [        "0xF25BEeF04aCC3550802B00e0bE45Dd593b73E4B7",
        "0x7447a4C251399E007719Eb61A83A21304443E5f1",
        "0x82c4443fCe54067a88f1FCf1753621489b3A1DE1",
        "0xC1D3e9c18Dae5184d8DF8E007F8Ea2849ECDe792",
        "0x8A3FE85B06142ED92ee889756D578C95c96bcdBC",
        "0x1355592A42eDA9C69C661d7762a6e53a27276E23",
        "0x03afEFa385ACee20349da88Fb107CDb9d5BE881e",
        "0x87808bdabbBB66Cc043a83F9327771a5218ca1f5",
        "0x002A6418581A2C14C7b239cf1cE7AF0F2Baf2B85",
        "0xCEd3d4F71934F9712449a14c06135283Dcdad260",
        "0x48a6983d0C7FF6bF24a5b1dBbE0C09Ea37b654b7"],
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

  let deployedImplementationAddress;

  if (contractToUpgrade.address) {
    deployedImplementationAddress = contractToUpgrade.address;
    console.log(
      `${contractToUpgrade.contractName} implementation already deployed at ${deployedImplementationAddress}`
    );
  } else {
    deployedImplementationAddress = (await deployContract(
      contractToUpgrade.contractName,
      contractToUpgrade.constructorArguments
    )).getAddress();
    console.log(
      `${contractToUpgrade.contractName} implementation deployed at ${deployedImplementationAddress}`
    );
  }

  const proxyOwnerWallet = getWallet(proxyOwnerPrivateKey);

  const transparentUpgradeableProxyArtifact = await hre.artifacts.readArtifact('ITransparentUpgradeableProxy');
  const transparentUpgradeableProxy = new ethers.Contract(transparentUpgradeableProxyAddress, transparentUpgradeableProxyArtifact.abi, proxyOwnerWallet);

  const upgradeTx = await transparentUpgradeableProxy.upgradeTo(
    deployedImplementationAddress
  );
  await upgradeTx.wait();

  const newImplementation = await hre.upgrades.erc1967.getImplementationAddress(transparentUpgradeableProxyAddress);

  if (newImplementation !== deployedImplementationAddress) {
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
