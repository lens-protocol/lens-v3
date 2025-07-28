// To run this script:
// 1. Make sure your .env file has PROXY_ADMIN_PRIVATE_KEY (current owner) and LENS_PROXY_ADMIN (new owner) set.
// 2. Run: npx hardhat run deploy/transferFactoryOwnerships.ts --network <your_network_name>

import {
    loadContractAddressFromAddressBook,
    promptForConfirmation,
  } from './lensUtils';
  import { getWallet } from './utils';
  import * as hre from 'hardhat';
  import { ethers, Wallet } from 'ethers';
  import 'dotenv/config';

  async function deploy() {
    console.log('\n\x1b[33m--- Transfer Factory Ownerships Script ---\x1b[0m');

    // --- 1. Check Network ---
    const chainId = Number((await hre.ethers.provider.getNetwork()).chainId);
    if (chainId === 232) {
      console.log('\x1b[32m');
      console.log('------------------------------------------------------------------');
      console.log('                          MAINNET (232)                           ');
      console.log('------------------------------------------------------------------');
      console.log('\x1b[0m');
    } else if (chainId === 37111) {
      console.log('\x1b[33m');
      console.log('------------------------------------------------------------------');
      console.log('                         TESTNET (37111)                          ');
      console.log('------------------------------------------------------------------');
      console.log('\x1b[0m');
    } else {
      console.log(`\x1b[31mUnknown network detected (Chain ID: ${chainId}). Aborting.\x1b[0m`);
      throw new Error('Unknown network');
    }

    // --- 2. Load Wallets & Addresses from .env ---
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

    // --- 3. Load Factory Contracts from Address Book ---
    console.log('\x1b[36mLoading contract addresses from addressBook.json...\x1b[0m');
    const factoriesToTransfer = [
      { name: 'AccountFactory', address: loadContractAddressFromAddressBook('AccountFactory') },
      { name: 'LensFactory', address: loadContractAddressFromAddressBook('LensFactory') },
    ];

    for (const factory of factoriesToTransfer) {
      if (!factory.address) {
        throw new Error(`\x1b[31m${factory.name} not found in addressBook.json\x1b[0m`);
      }
    }

    // --- 4. Verify Current Ownership ---
    console.log('\n\x1b[33mVerifying current ownership of proxies...\x1b[0m');
    for (const factory of factoriesToTransfer) {
      const onChainAdmin = await hre.upgrades.erc1967.getAdminAddress(factory.address!);
      console.log(
        `\t\x1b[36m- ${factory.name} at ${factory.address} has admin: ${onChainAdmin}\x1b[0m`
      );

      if (onChainAdmin.toLowerCase() !== lensAccountAddress.toLowerCase()) {
        throw new Error(
          `\x1b[31mOwnership mismatch for ${factory.name}! Expected Lens Account (${lensAccountAddress}) but found ${onChainAdmin}. Aborting.\x1b[0m`
        );
      }
    }
    console.log('\x1b[32mCurrent ownership by Lens Account verified successfully.\x1b[0m');

    const newAdminAddress = lensAccountOwnerAddress;

    // --- 5. User Confirmation Prompt ---
    console.log(`\n\x1b[36mThe new Proxy Admin for these factories will be: ${newAdminAddress}\x1b[0m`);

    const confirmed = await promptForConfirmation(
      '\x1b[33mDo you want to proceed with the ownership transfer? (y/n): \x1b[0m'
    );

    if (!confirmed) {
      console.log('\x1b[31mTransfer cancelled by user.\x1b[0m');
      return;
    }

    // --- 6. Execute Transfer ---
    console.log('\n\x1b[32mProceeding with ownership transfer...\x1b[0m');

    const proxyArtifact = await hre.artifacts.readArtifact('ITransparentUpgradeableProxy');
    const lensAccountArtifact = await hre.artifacts.readArtifact('Account');

    // Create array of transactions for batch execution
    const transactions = factoriesToTransfer.map(factory => ({
      target: factory.address!,
      value: 0,
      data: new ethers.Interface(proxyArtifact.abi).encodeFunctionData('changeAdmin', [newAdminAddress])
    }));

    // Execute all transfers in one transaction via Account
    const lensAccountInstance = new ethers.Contract(lensAccountAddress, lensAccountArtifact.abi, lensAccountOwnerWallet);
    const tx = await lensAccountInstance.executeTransactions(transactions);
    await tx.wait();

    console.log(`\t\x1b[32m✔ Admin changed for all factories in one transaction. Tx: ${tx.hash}\x1b[0m`);

    // --- 7. Verify New Ownership ---
    console.log('\n\x1b[33mVerifying new ownership of proxies...\x1b[0m');
    let allVerified = true;
    for (const factory of factoriesToTransfer) {
      const onChainAdmin = await hre.upgrades.erc1967.getAdminAddress(factory.address!);
      console.log(`\t\x1b[36m- ${factory.name} new admin: ${onChainAdmin}\x1b[0m`);
      if (onChainAdmin.toLowerCase() !== newAdminAddress.toLowerCase()) {
        console.log(`\t\x1b[31mERROR: New admin for ${factory.name} is ${onChainAdmin}, but expected ${newAdminAddress}\x1b[0m`);
        allVerified = false;
      }
    }

    if (!allVerified) {
      throw new Error('\x1b[31mVerification failed! One or more factories were not transferred correctly.\x1b[0m');
    }

    console.log('\n\x1b[32m✅ Successfully transferred and verified ownership for all factories!\x1b[0m');
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
