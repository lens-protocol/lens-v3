import { deployLensContract, promptForConfirmation, loadContractAddressFromAddressBook, loadContractFromAddressBook, saveContractToAddressBook } from './lensUtils';
import { getWallet } from './utils';
import * as hre from 'hardhat';
import { ethers } from 'ethers';

async function deploy() {
  const lensAccountAddress = process.env.LENS_PROXY_ADMIN;
  if (!lensAccountAddress) {
    throw new Error('\x1b[31mLENS_PROXY_ADMIN is not set in .env file. This is the Lens Account.\x1b[0m');
  }

  const lensAccountOwnerPk = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!lensAccountOwnerPk) {
    throw new Error('\x1b[31mPROXY_ADMIN_PRIVATE_KEY not set in .env file. This is the current owner of the Lens Account.\x1b[0m');
  }

  const lensAccountOwnerWallet = getWallet(lensAccountOwnerPk);
  const lensAccountOwnerAddress = await lensAccountOwnerWallet.getAddress();
  console.log(`\x1b[36mSigner (Current Lens Account Owner): ${lensAccountOwnerAddress}\x1b[0m`);


  // Get the owner of the Lens Account that will be the new admin
  const accountArtifact = await hre.artifacts.readArtifact('IOwnable');
  const accountContract = new ethers.Contract(lensAccountAddress, accountArtifact.abi, lensAccountOwnerWallet);
  const accountOwner = await accountContract.owner();
  if (accountOwner.toLowerCase() !== lensAccountOwnerAddress.toLowerCase()) {
    throw new Error('\x1b[31mThe Lens Account is not owned by the current owner.\x1b[0m');
  }

  const lensAccountOwnerBalance = await getWallet(lensAccountOwnerPk).getBalance();
  if (lensAccountOwnerBalance < ethers.parseEther('0.01')) {
    throw new Error('\x1b[31mLens Account Owner balance is less than 0.01 ETH\x1b[0m');
  }

  console.log(`\x1b[36mLens Account Owner balance: ${ethers.formatEther(lensAccountOwnerBalance)}\x1b[0m`);

  // --- 3. Load Factory Contracts from Address Book ---
  console.log('\x1b[36mLoading contract addresses from addressBook.json...\x1b[0m');
  const factoriesToUpgrade = [
    loadContractFromAddressBook('AccountFactory'),
    loadContractFromAddressBook('LensFactory'),
  ];

  for (const factory of factoriesToUpgrade) {
    if (!factory || !factory.address) {
      throw new Error(`\x1b[31m${factory?.name} not found in addressBook.json\x1b[0m`);
    }
  }

  // --- 4. Load New Implementations from Address Book ---
  const newImplementations = [
    loadContractFromAddressBook('AccountFactoryImpl'),
    loadContractFromAddressBook('LensFactoryImpl'),
  ];

  for (const implementation of newImplementations) {
    if (!implementation || !implementation.address) {
      throw new Error(`\x1b[31m${implementation?.name} not found in addressBook.json\x1b[0m`);
    }
  }

  // --- 5. Verify Current Implementation VS New Implementation ---
  console.log('\n\x1b[33mVerifying current implementation vs new implementation...\x1b[0m');
  for (const factory of factoriesToUpgrade) {
    const onChainImplementationAddress = await hre.upgrades.erc1967.getImplementationAddress(factory!.address!);
    console.log(
      `\t\x1b[36m- ${factory!.name} at ${factory!.address} current implementation: ${onChainImplementationAddress}\x1b[0m`
    );

    const newImplementation = newImplementations.find(impl => impl!.name === factory!.name + 'Impl');
    if (onChainImplementationAddress == newImplementation!.address) {
      throw new Error(`\x1b[31m${factory!.name} current implementation (${onChainImplementationAddress}) already matches new one (${newImplementation!.address})\x1b[0m`);
    } else {
      console.log(`\t\x1b[36m- \t\tnew implementation: ${newImplementation!.address}\x1b[0m`);
      factory!.implementation = newImplementation!.address;
    }
  }

  // --- 6. User Confirmation Prompt ---
  const confirmed = await promptForConfirmation(
    '\x1b[33mDo you want to proceed with the upgrade? (y/n): \x1b[0m'
  );

  if (!confirmed) {
    console.log('\x1b[31mTransfer cancelled by user.\x1b[0m');
    return;
  }

  // --- 7. Execute Upgrade ---
  console.log('\n\x1b[32mProceeding with upgrade...\x1b[0m');

  const proxyArtifact = await hre.artifacts.readArtifact('ITransparentUpgradeableProxy');
  const lensAccountArtifact = await hre.artifacts.readArtifact('Account');

  // Create array of transactions for batch execution
  const transactions = factoriesToUpgrade.map(factory => ({
    target: factory!.address!,
    value: 0,
    data: new ethers.Interface(proxyArtifact.abi).encodeFunctionData('upgradeTo', [factory!.implementation])
  }));

  console.log(transactions.map(t => t.data));

  // Execute all transfers in one transaction via Account
  const lensAccountInstance = new ethers.Contract(lensAccountAddress, lensAccountArtifact.abi, lensAccountOwnerWallet);
  const tx = await lensAccountInstance.executeTransactions(transactions);
  await tx.wait();

  console.log(`\t\x1b[32m✔ Upgrade for all factories in one transaction. Tx: ${tx.hash}\x1b[0m`);

  for (const factory of factoriesToUpgrade) {
    saveContractToAddressBook({
      ...factory!,
      implementation: factory!.implementation,
    });
  }
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
