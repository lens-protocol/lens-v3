// To run this script:
// 1. Make sure your .env file has PROXY_ADMIN_PRIVATE_KEY (current owner) and LENS_PROXY_ADMIN (new owner) set.
// 2. Run: npx hardhat run deploy/transferFactoryOwnershipsToSafe.ts --network <your_network_name>

import {
    loadContractAddressFromAddressBook,
    promptForConfirmation,
    getContractBytecodeHashByAddress
  } from './lensUtils';
  import { getWallet } from './utils';
  import * as hre from 'hardhat';
  import { ethers, Wallet } from 'ethers';
  import 'dotenv/config';

  const safeBytecodeHash = '0100003b6cfa15bd7d1cae1c9c022074524d7785d34859ad0576d8fab4305d4f';

  async function deploy() {
    console.log('\n\x1b[33m--- Transfer Factory Ownerships to Safe Script ---\x1b[0m');

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
    const currentAdminPk = process.env.PROXY_ADMIN_PRIVATE_KEY;
    if (!currentAdminPk) {
      throw new Error('\x1b[31mPROXY_ADMIN_PRIVATE_KEY not set in .env file. This is the current owner.\x1b[0m');
    }

    const newAdminAddress = process.env.LENS_PROXY_ADMIN;
    if (!newAdminAddress || !ethers.isAddress(newAdminAddress)) {
      throw new Error('\x1b[31mLENS_PROXY_ADMIN is not set or is not a valid address in .env file. This is the new owner.\x1b[0m');
    }

    const currentAdminWallet = getWallet(currentAdminPk);
    const currentAdminAddress = await currentAdminWallet.getAddress();
    console.log(`\x1b[36mSigner (Current Admin): ${currentAdminAddress}\x1b[0m`);

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

      if (onChainAdmin.toLowerCase() !== currentAdminAddress.toLowerCase()) {
        throw new Error(
          `\x1b[31mOwnership mismatch for ${factory.name}! Expected ${currentAdminAddress} but found ${onChainAdmin}. Aborting.\x1b[0m`
        );
      }
    }
    console.log('\x1b[32mCurrent ownership verified successfully.\x1b[0m');

    // --- 5. User Confirmation Prompt ---
    console.log(`\n\x1b[36mThe new Proxy Admin for these factories will be: ${newAdminAddress}\x1b[0m`);

    // Get the bytecode hash of the Safe Account that will be the new admin
    const accountBytecodeHash = await getContractBytecodeHashByAddress(newAdminAddress);
    if (accountBytecodeHash !== safeBytecodeHash) {
      throw new Error(`\x1b[31mThis is not a Safe Account - bytecode hash differs from expected: ${safeBytecodeHash} (expected) vs ${accountBytecodeHash} (actual)\x1b[0m`);
    } else {
      console.log(`\x1b[36mThis is a Safe Account with bytecode hash: ${accountBytecodeHash}\x1b[0m`);
    }

    // getOwners() of the Safe Account
    const safeAbi = [
      {
        type: "function",
        name: "getOwners",
        inputs: [],
        outputs: [{ type: "address[]", name: "owners" }],
        stateMutability: "view",
      },
      {
        type: "function",
        name: "getThreshold",
        inputs: [],
        outputs: [{ type: "uint256", name: "threshold" }],
        stateMutability: "view",
      },
    ];
    const safeContract = new ethers.Contract(newAdminAddress, safeAbi, currentAdminWallet);
    const owners = await safeContract.getOwners();
    const threshold = await safeContract.getThreshold();
    console.log(`\x1b[36mOwners of the Safe Account:\x1b[0m`);
    for (const owner of owners) {
      console.log(`\t${owner}`);
    }
    console.log(`\x1b[36mThreshold of the Safe Account: ${threshold} out of ${owners.length} owners\x1b[0m`);

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

    for (const factory of factoriesToTransfer) {
      console.log(`\tChanging admin for ${factory.name}...`);
      const proxyContract = new ethers.Contract(factory.address!, proxyArtifact.abi, currentAdminWallet);
      const tx = await proxyContract.changeAdmin(newAdminAddress);
      await tx.wait();
      console.log(`\t\x1b[32m✔ Admin for ${factory.name} changed. Tx: ${tx.hash}\x1b[0m`);
    }

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
