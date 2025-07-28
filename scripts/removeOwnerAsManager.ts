import { ethers } from 'ethers';
import * as fs from 'fs';
import * as path from 'path';
import 'dotenv/config';

// Multicall contract ABI for aggregate function
const MULTICALL_ABI = [
  {
    "inputs": [
      {
        "components": [
          {
            "internalType": "address",
            "name": "target",
            "type": "address"
          },
          {
            "internalType": "bytes",
            "name": "callData",
            "type": "bytes"
          }
        ],
        "internalType": "struct Multicall3.Call[]",
        "name": "calls",
        "type": "tuple[]"
      }
    ],
    "name": "aggregate",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "blockNumber",
        "type": "uint256"
      },
      {
        "internalType": "bytes[]",
        "name": "returnData",
        "type": "bytes[]"
      }
    ],
    "stateMutability": "payable",
    "type": "function"
  }
];

// Account contract ABI for removeOwnerAsManager function
const ACCOUNT_ABI = [
  {
    "inputs": [],
    "name": "removeOwnerAsManager",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

const MULTICALL_ADDRESS = '0x6b6dEa4D80e3077D076733A04c48F63c3BA49320';
const BATCH_SIZE = 100;

async function main() {
  // Check if private key is provided
  const privateKey = process.env.WALLET_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error('WALLET_PRIVATE_KEY environment variable is required');
  }

  // Read addresses from CSV file
  const csvPath = path.join(__dirname, '..', 'ownerAsManager.csv');
  const csvContent = fs.readFileSync(csvPath, 'utf8');

  // Parse addresses (remove empty lines and add 0x prefix)
  const addresses = csvContent
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.length > 0)
    .map(address => `0x${address}`);

  console.log(`Found ${addresses.length} addresses to process`);

  // Setup provider and wallet
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL || 'https://api.lens.matterhosted.dev/');
  const wallet = new ethers.Wallet(privateKey, provider);

  // Create contract instances
  const multicallContract = new ethers.Contract(MULTICALL_ADDRESS, MULTICALL_ABI, wallet);
  const accountInterface = new ethers.Interface(ACCOUNT_ABI);

  // Process addresses in batches
  for (let i = 0; i < addresses.length; i += BATCH_SIZE) {
    const batch = addresses.slice(i, i + BATCH_SIZE);
    console.log(`Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(addresses.length / BATCH_SIZE)} (${batch.length} addresses)`);

    // Prepare multicall data
    const calls = batch.map(address => ({
      target: address,
      callData: accountInterface.encodeFunctionData('removeOwnerAsManager')
    }));

    try {
      // Execute multicall
      const tx = await multicallContract.aggregate(calls);
      console.log(`Transaction hash: ${tx.hash}`);

      // Wait for transaction confirmation
      const receipt = await tx.wait();
      console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

      // Check if any calls failed
      const returnData = receipt.logs[0]?.data;
      if (returnData) {
        console.log('All calls in batch completed successfully');
      }

    } catch (error) {
      console.error(`Error processing batch starting at index ${i}:`, error);
      // Continue with next batch even if this one fails
    }

    // Add a small delay between batches to avoid rate limiting
    if (i + BATCH_SIZE < addresses.length) {
      console.log('Waiting 2 seconds before next batch...');
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }

  console.log('All batches processed');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
