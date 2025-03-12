import { execSync } from 'child_process';
import crypto from 'crypto';
import dotenv from 'dotenv';
import { ContractType, loadAddressBook, ContractInfo } from '../deploy/lensUtils';
import fs from 'fs';
import path from 'path';

dotenv.config();

const RPC_URL = process.env.RPC_URL;

if (!RPC_URL) {
  console.error('RPC_URL is not set');
  process.exit(1);
}

// Get address from command line argument
const addressBook = loadAddressBook();

const bytecodeHashes = getBytecodeHashesFromArtifacts();

function getBytecode(address: string): string {
  try {
    const result = execSync(`cast code ${address} --rpc-url ${RPC_URL}`, { encoding: 'utf8' });
    return result.trim();
  } catch (error) {
    console.error(`Error fetching bytecode for ${address}:`, error);
    process.exit(1);
  }
}

function getBeaconImplementation(address: string): string {
  try {
    const result = execSync(`cast call ${address} "implementation()" --rpc-url ${RPC_URL}`, {
      encoding: 'utf8',
    });
    return '0x' + result.trim().slice(2 + 24);
  } catch (error) {
    console.error(`Error fetching implementation for ${address}:`, error);
    process.exit(1);
  }
}

function getBeacon(address: string): string {
  try {
    const result = execSync(`cast call ${address} "proxy__getBeacon()" --rpc-url ${RPC_URL}`, {
      encoding: 'utf8',
    });
    return '0x' + result.trim().slice(2 + 24);
  } catch (error) {
    console.error(`Error fetching implementation for ${address}:`, error);
    process.exit(1);
  }
}

function getTransparentProxyImplementation(address: string): string {
  try {
    const implSlot = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
    const result = execSync(`cast storage ${address} ${implSlot} --rpc-url ${RPC_URL}`, {
      encoding: 'utf8',
    });
    return '0x' + result.trim().slice(2 + 24);
  } catch (error) {
    console.error(`Error fetching implementation for ${address}:`, error);
    process.exit(1);
  }
}

function getBytecodeHashesFromArtifacts(): Record<string, string> {
  const artifactsDir = path.join(__dirname, '../artifacts-zk/contracts');
  const bytecodeHashes: Record<string, string> = {};

  function processDirectory(directory: string) {
    const files = fs.readdirSync(directory);

    for (const file of files) {
      const fullPath = path.join(directory, file);
      const stats = fs.statSync(fullPath);

      if (stats.isDirectory()) {
        processDirectory(fullPath);
      } else if (file.endsWith('.json')) {
        try {
          const artifact = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
          if (artifact.bytecode) {
            const hash = hashBytecode(artifact.bytecode);
            const fileName = path.parse(file).name;
            bytecodeHashes[fileName] = hash;
          }
        } catch (error) {
          console.error(`Error processing ${fullPath}:`, error);
        }
      }
    }
  }

  processDirectory(artifactsDir);
  return bytecodeHashes;
}

function hashBytecode(bytecode: string): string {
  try {
    // Remove 0x prefix if present
    if (bytecode.startsWith('0x')) {
      bytecode = bytecode.slice(2);
    }

    // Convert hex string to bytes
    const bytecodeBytes = Buffer.from(bytecode, 'hex');

    // Calculate SHA256
    const hash = crypto.createHash('sha256').update(bytecodeBytes).digest();

    // Modify hash according to the same rules as in Python script
    const hashBytes = Buffer.from(hash);
    hashBytes[0] = 1;
    hashBytes[1] = 0;

    // Set length of bytecode in bytes 2-3
    const bytecodeLength = Math.floor(bytecodeBytes.length / 32);
    hashBytes[2] = (bytecodeLength >> 8) & 0xff;
    hashBytes[3] = bytecodeLength & 0xff;

    return '0x' + hashBytes.toString('hex');
  } catch (error) {
    console.error('Error hashing bytecode:', error);
    process.exit(1);
  }
}

function verifyBeacon(primitiveName: string): string {
  const deploymentName = `${primitiveName}Beacon`;
  const contractInfo = addressBook[deploymentName];
  if (contractInfo.contractName != 'Beacon' || contractInfo.contractType != ContractType.Beacon) {
    console.error(`${deploymentName} is not a Beacon`);
    process.exit(1);
  }

  const implementation = getBeaconImplementation(contractInfo.address!);
  // console.log(`Address of ${deploymentName} implementation: ${implementation}`);

  // Search all entries of the addressbook for .address matching the implementation address - and find the key
  const implementationKey = Object.keys(addressBook).find(
    (key: string) => addressBook[key].address?.toLowerCase() === implementation.toLowerCase()
  );

  if (!implementationKey) {
    console.error(`Implementation address ${implementation} not found in address book`);
    process.exit(1);
  }
  const implementationContractInfo = addressBook[implementationKey];

  if (
    implementationContractInfo.contractType != ContractType.Implementation ||
    implementationKey != `${primitiveName}Impl`
  ) {
    console.error(`Implementation address ${implementation} is not a ${primitiveName}`);
    process.exit(1);
  }

  console.log(
    `\x1b[32mAddresses match! ${deploymentName} === ${primitiveName}Impl! Implementation used: ${implementationContractInfo.contractName}\x1b[0m`
  );

  const bytecode = getBytecode(implementationContractInfo.address!);
  const hash = hashBytecode(bytecode);

  // Search for the hash in bytecodeHashes based on the hash
  const artifactName = Object.keys(bytecodeHashes).find(
    (key: string) => bytecodeHashes[key] === hash
  );
  if (!artifactName) {
    console.error(`Bytecode hash ${hash} not found in artifacts`);
    process.exit(1);
  }

  if (artifactName != implementationContractInfo.contractName) {
    console.error(
      `Bytecode hash ${hash} found in artifacts but contract name ${artifactName} does not match ${implementationContractInfo.contractName}`
    );
    process.exit(1);
  }

  console.log(`\x1b[32mBytecodes match! ${deploymentName} >>> ${artifactName}\x1b[0m`);

  return contractInfo.address!;
}

function verifyTransparentProxy(deploymentName: string) {
  const contractInfo = addressBook[deploymentName];

  const implementation = getTransparentProxyImplementation(contractInfo.address!);

  // Search all entries of the addressbook for .address matching the implementation address - and find the key
  const implementationKey = Object.keys(addressBook).find(
    (key: string) => addressBook[key].address?.toLowerCase() === implementation.toLowerCase()
  );

  if (!implementationKey) {
    console.error(`Implementation address ${implementation} not found in address book`);
    process.exit(1);
  }

  const implementationContractInfo = addressBook[implementationKey];

  const bytecode = getBytecode(implementationContractInfo.address!);
  const hash = hashBytecode(bytecode);

  // Search for the hash in bytecodeHashes based on the hash
  const artifactName = Object.keys(bytecodeHashes).find(
    (key: string) => bytecodeHashes[key] === hash
  );
  if (!artifactName) {
    console.error(`Bytecode hash ${hash} not found in artifacts`);
    process.exit(1);
  }

  if (artifactName != implementationContractInfo.contractName) {
    console.error(
      `Bytecode hash ${hash} found in artifacts but contract name ${artifactName} does not match ${implementationContractInfo.contractName}`
    );
    process.exit(1);
  }

  console.log(`\x1b[32mBytecodes match! ${deploymentName} >>> ${artifactName}\x1b[0m`);
}

function verifyPrimitive(primitiveName: string) {
  const deploymentName = `LensGlobal${primitiveName}`;
  const contractInfo = addressBook[deploymentName];

  if (
    contractInfo.contractName != primitiveName ||
    contractInfo.contractType != ContractType.Primitive
  ) {
    console.error(`${deploymentName} is not a ${primitiveName}`);
    process.exit(1);
  }

  const beacon = getBeacon(contractInfo.address!);
  console.log(
    `\x1b[32mBeacon for ${deploymentName} is ${contractInfo.contractName} (as BeaconProxy)\x1b[0m`
  );

  const beaconAddress = verifyBeacon(primitiveName);
  if (beaconAddress.toLowerCase() != beacon.toLowerCase()) {
    console.error(`Beacon address for ${deploymentName} does not match ${beacon}`);
    process.exit(1);
  }
  console.log(
    `\x1b[32mBeacon address for ${deploymentName} matches addressbook: ${beaconAddress}\x1b[0m`
  );
}

function verifyWhitelistedMulticall() {
  // Extract the address from WhitelistedMulticall.sol using regex
  const whitelistedMulticallFile = fs.readFileSync(
    path.join(__dirname, '../contracts/migration/WhitelistedMulticall.sol'),
    'utf8'
  );
  const addressMatch = whitelistedMulticallFile.match(
    /address constant WHITELISTED_MULTICALL_ADDRESS = (0x[a-fA-F0-9]{40})/
  );

  if (!addressMatch) {
    console.error('Could not find WHITELISTED_MULTICALL_ADDRESS in WhitelistedMulticall.sol');
    process.exit(1);
  }

  const whitelistedMulticallProxyAddress = addressMatch[1];

  const whitelistedMulticallAddress = getTransparentProxyImplementation(whitelistedMulticallProxyAddress);

  // Get bytecode and hash it
  const bytecode = getBytecode(whitelistedMulticallAddress);
  const hash = hashBytecode(bytecode);

  // Find matching artifact
  const artifactName = Object.keys(bytecodeHashes).find(
    (key: string) => bytecodeHashes[key] === hash
  );
  if (!artifactName) {
    console.error(`Bytecode hash ${hash} not found in artifacts`);
    console.error(`Hash of WhitelistedMulticall is : ${bytecodeHashes['WhitelistedMulticall']}`);
    process.exit(1);
  }

  if (artifactName !== 'WhitelistedMulticall') {
    console.error(
      `Bytecode hash ${hash} found in artifacts but contract name ${artifactName} does not match WhitelistedMulticall`
    );
    process.exit(1);
  }

  console.log(`\x1b[32mBytecodes match! WhitelistedMulticall >>> ${artifactName}\x1b[0m`);
}

const lensPrimitivesToVerify = ['Feed', 'Namespace', 'Graph'];

const beaconsToVerify = ['App', 'Account', 'Feed', 'Graph', 'Group', 'Namespace'];

const transparentProxiesToVerify = [
  'AccessControlFactory',
  'AccountFactory',
  'AppFactory',
  'FeedFactory',
  'GraphFactory',
  'NamespaceFactory',
  'LensFactory',
];

function main() {
  // Verify WhitelistedMulticall
  console.log('\nVerifying WhitelistedMulticall');
  console.log('=============================');
  verifyWhitelistedMulticall();

  // Verify Lens Primitives
  console.log('\nVerifying Lens Primitives');
  console.log('=========================');
  for (const primitive of lensPrimitivesToVerify) {
    verifyPrimitive(primitive);
  }

  // Verify Beacons
  console.log('\nVerifying Beacons');
  console.log('=================');
  for (const beacon of beaconsToVerify) {
    verifyBeacon(beacon);
  }

  // Verify Transparent Proxies
  console.log('\nVerifying Transparent Proxies');
  console.log('=============================');
  for (const proxy of transparentProxiesToVerify) {
    verifyTransparentProxy(proxy);
  }
}

main();
