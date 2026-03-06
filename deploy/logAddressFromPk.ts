// SPDX-License-Identifier: GPL-3.0-only

import { ethers } from 'ethers';
import { getWallet } from './utils';

/**
 * This script logs the address derived from a private key and its balance.
 *
 * To run this script:
 *
 *     npx hardhat deploy-zksync --script logAddressFromPk.ts --network <network>
 */

async function deploy() {
  /////////////////// SETUP ///////////////////

  const pk = process.env.SOME_PK; // Set your private key here from .env file
  if (!pk) {
    throw new Error('Private key not found in environment variables');
  }

  /////////////////////////////////////////////

  const wallet = getWallet(pk);
  const balance = await wallet.getBalance();
  const address = await wallet.getAddress();

  console.log(`Private key's derived address: ${address}`);
  console.log(`Address balance: ${ethers.formatEther(balance)}`);
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
