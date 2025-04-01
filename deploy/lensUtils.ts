import fs from 'fs';
import { deployContract } from './utils';
import { keccak256 } from 'ethers';
import * as hre from 'hardhat';

export enum ContractType {
  Implementation,
  Beacon,
  Factory,
  Primitive,
  Aux,
  Action,
  Rule,
  Misc,
  Address,
}

export interface ContractInfo {
  name?: string;
  contractName: string;
  contractType: ContractType;
  address?: string;
  constructorArguments?: any[];
  bytecodeHash?: string;
  implementation?: string;
}

export type AddressBook = Record<string, Omit<ContractInfo, 'name'>>;

export function loadAddressBook(): AddressBook {
  try {
    const addressBook = require('../addressBook.json');
    return addressBook;
  } catch (e) {
    return {};
  }
}

export function saveAddressBook(addressBook: any) {
  fs.writeFileSync('addressBook.json', JSON.stringify(addressBook, null, 2));
}

export function saveContractToAddressBook(contract: ContractInfo) {
  const addressBook = loadAddressBook();
  addressBook[contract.name ?? contract.contractName] = contract;
  saveAddressBook(addressBook);
}

export function loadContractFromAddressBook(name: string): ContractInfo | undefined {
  const addressBook = loadAddressBook();
  return addressBook[name];
}

export function loadContractAddressFromAddressBook(name: string): string | undefined {
  const addressBook = loadAddressBook();
  return addressBook[name]?.address;
}

export async function deployLensContract(contractToDeploy: ContractInfo, override: Boolean = false): Promise<ContractInfo> {
  const name = contractToDeploy.name ?? contractToDeploy.contractName;

  const artifact = await hre.artifacts.readArtifact(contractToDeploy.contractName);
  const bytecodeHash = calculateBytecodeHash(artifact.bytecode);

  // Check address book for existing contract
  const addressBook = loadAddressBook();
  const existingContract = addressBook[name];

  if (existingContract && existingContract.bytecodeHash === bytecodeHash && override == false) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return {
      name: contractToDeploy.name,
      ...existingContract,
    };
  } else {
    console.log(`Deploying ${name}...`);
    if (contractToDeploy.constructorArguments) {
      console.log('\tUsing the following Constructor arguments:');
      for (const arg of contractToDeploy.constructorArguments) {
        console.log('\t\t', arg);
      }
    }
  }

  const deployedContract = await deployContract(
    contractToDeploy.contractName,
    contractToDeploy.constructorArguments
  );
  const contractInfo: ContractInfo = {
    contractName: contractToDeploy.contractName,
    contractType: contractToDeploy.contractType,
    address: await deployedContract.getAddress(),
    bytecodeHash,
    constructorArguments: contractToDeploy.constructorArguments,
  };

  addressBook[name] = contractInfo;
  saveAddressBook(addressBook);

  return {
    name: contractToDeploy.name,
    ...contractInfo,
  };
}

export async function deployLensContractAsProxy(
  contractToDeploy: ContractInfo,
  proxyOwner: string
): Promise<ContractInfo> {
  const name = contractToDeploy.name ?? contractToDeploy.contractName;

  const artifact = await hre.artifacts.readArtifact(contractToDeploy.contractName);
  const bytecodeHash = calculateBytecodeHash(artifact.bytecode);

  // Check address book for existing contract
  const addressBook = loadAddressBook();
  const existingContract = addressBook[name];

  if (existingContract) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return {
      name: contractToDeploy.name,
      ...existingContract,
    };
  } else {
    console.log(`Deploying ${name} (as upgradeable proxy)...`);
  }

  const deployedImplementation = await deployContract(
    contractToDeploy.contractName,
    contractToDeploy.constructorArguments
  );

  const contractInfo: ContractInfo = {
    name: contractToDeploy.name ?? contractToDeploy.contractName + 'Impl',
    contractName: contractToDeploy.contractName,
    contractType: ContractType.Implementation,
    address: await deployedImplementation.getAddress(),
    bytecodeHash,
    constructorArguments: contractToDeploy.constructorArguments,
  };

  addressBook[contractToDeploy.name ?? contractToDeploy.contractName + 'Impl'] = contractInfo;
  saveAddressBook(addressBook);

  const constructorArguments = [await deployedImplementation.getAddress(), proxyOwner, '0x'];
  const deployedProxy = await deployContract('TransparentUpgradeableProxy', constructorArguments);
  const proxyArtifact = await hre.artifacts.readArtifact('TransparentUpgradeableProxy');
  const proxyBytecodeHash = calculateBytecodeHash(proxyArtifact.bytecode);

  const proxyInfo: ContractInfo = {
    name: contractToDeploy.name,
    contractName: 'TransparentUpgradeableProxy',
    contractType: contractToDeploy.contractType,
    address: await deployedProxy.getAddress(),
    bytecodeHash: proxyBytecodeHash,
    constructorArguments,
    implementation: await deployedImplementation.getAddress(),
  };

  addressBook[name] = proxyInfo;
  saveAddressBook(addressBook);

  return {
    name: contractToDeploy.name,
    ...proxyInfo,
  };
}

export function mapContractNameToEnvVarName(contractName: string): string {
  if (contractName === 'LensGlobalFeed') {
    return 'GLOBAL_FEED';
  } else if (contractName === 'LensGlobalGraph') {
    return 'GLOBAL_GRAPH';
  } else if (contractName === 'LensGlobalNamespace') {
    return 'LENS_NAMESPACE';
  } else {
    return contractName
      .replace(/([a-z])([A-Z])/g, '$1_$2') // Insert underscore between lowercase and uppercase letters
      .toUpperCase(); // Convert to uppercase
  }
}

export function generateEnvFile() {
  console.log('Generating env file...');
  const addressBook = loadAddressBook();
  let output = '';

  // Group contracts by type
  const factories: string[] = [];
  const implementations: string[] = [];
  const beacons: string[] = [];
  const actions: string[] = [];
  const rules: string[] = [];
  const primitives: string[] = [];
  const aux: string[] = [];
  const misc: string[] = [];
  const addresses: string[] = [];
  for (const [contractName, info] of Object.entries(addressBook as AddressBook)) {
    if (!info.address) continue;

    const envVarName = mapContractNameToEnvVarName(contractName);
    const line = `${envVarName}="${info.address}"`;

    switch (info.contractType) {
      case ContractType.Factory: // Using enum instead of magic numbers
        factories.push(line);
        break;
      case ContractType.Implementation:
        implementations.push(line);
        break;
      case ContractType.Beacon:
        beacons.push(line);
        break;
      case ContractType.Primitive:
        primitives.push(line);
        break;
      case ContractType.Aux:
        aux.push(line);
        break;
      case ContractType.Action:
        actions.push(line);
        break;
      case ContractType.Rule:
        rules.push(line);
        break;
      case ContractType.Misc:
        misc.push(line);
        break;
      case ContractType.Address:
        addresses.push(line);
        break;
    }
  }

  // Build output string
  output += '# FACTORIES\n';
  output += factories.join('\n');
  output += '\n\n';

  if (primitives.length > 0) {
    output += '# IMPLEMENTATIONS\n';
    output += implementations.join('\n');
    output += '\n\n';
  }

  if (primitives.length > 0) {
    output += '# BEACONS\n';
    output += beacons.join('\n');
    output += '\n\n';
  }

  if (primitives.length > 0) {
    output += '# LENS GLOBAL PRIMITIVES\n';
    output += primitives.join('\n');
    output += '\n\n';
  }

  if (aux.length > 0) {
    output += '# AUX\n';
    output += aux.join('\n');
    output += '\n\n';
  }

  if (actions.length > 0) {
    output += '# ACTIONS\n';
    output += actions.join('\n');
    output += '\n\n';
  }

  if (rules.length > 0) {
    output += '# RULES\n';
    output += rules.join('\n');
    output += '\n\n';
  }

  if (misc.length > 0) {
    output += '# MISC\n';
    output += misc.join('\n');
    output += '\n';
  }

  if (addresses.length > 0) {
    output += '# CONSTANTS / ADDRESSES\n';
    output += addresses.join('\n');
    output += '\n';
  }

  fs.writeFileSync('contracts.env', output);
}

function calculateBytecodeHash(bytecode: string): string {
  // Remove '0x' prefix if present
  const cleanBytecode = bytecode.startsWith('0x') ? bytecode.slice(2) : bytecode;

  // Convert hex string to byte array
  const byteArray = Buffer.from(cleanBytecode, 'hex');

  // Calculate SHA256 hash
  const hash = Buffer.from(require('crypto').createHash('sha256').update(byteArray).digest());

  // Modify first 4 bytes according to spec
  hash[0] = 1;
  hash[1] = 0;

  // Set bytes 2-3 to length/32 as uint16
  const lenBytes = Buffer.alloc(2);
  lenBytes.writeUInt16BE(byteArray.length / 32);
  hash[2] = lenBytes[0];
  hash[3] = lenBytes[1];

  return hash.toString('hex');
}
