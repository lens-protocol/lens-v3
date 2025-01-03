import fs from 'fs';
import { deployContract } from './utils';
import { keccak256 } from 'ethers';
import * as hre from 'hardhat';

export enum ContractType {
  Factory,
  Implementation,
  Primitive,
  Aux,
  Action,
  Rule,
  Misc
}

export interface ContractInfo {
  contractName: string;
  contractType: ContractType;
  address?: string;
  constructorArguments?: any[];
  bytecodeHash?: string;
}

export type AddressBook = Record<string, Omit<ContractInfo, 'contractName'>>;

export function loadAddressBook() {
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
  addressBook[contract.contractName] = contract;
  saveAddressBook(addressBook);
}

export function loadContractFromAddressBook(contractName: string): ContractInfo | undefined {
  const addressBook = loadAddressBook();
  return addressBook[contractName];
}

export function loadContractAddressFromAddressBook(contractName: string): string | undefined {
  const addressBook = loadAddressBook();
  return addressBook[contractName]?.address;
}

export async function deployLensContract(contractToDeploy: ContractInfo): Promise<ContractInfo> {
  const artifact = await hre.artifacts.readArtifact(contractToDeploy.contractName);
  const bytecodeHash = keccak256(artifact.bytecode);

  // Check address book for existing contract
  const addressBook = loadAddressBook();
  const existingContract = addressBook[contractToDeploy.contractName];

  if (existingContract && existingContract.bytecodeHash === bytecodeHash) {
    console.log(`${contractToDeploy.contractName} already deployed at ${existingContract.address}. Skipping...`);
    return {
      contractName: contractToDeploy.contractName,
      ...existingContract,
    };
  }

  const deployedContract = await deployContract(
    contractToDeploy.contractName,
    contractToDeploy.constructorArguments
  );
  const contractInfo = {
    contractType: contractToDeploy.contractType,
    address: await deployedContract.getAddress(),
    bytecodeHash,
  };

  addressBook[contractToDeploy.contractName] = contractInfo;
  saveAddressBook(addressBook);

  return {
    contractName: contractToDeploy.contractName,
    ...contractInfo,
  };
}

export function camelToAllCaps(camelCase: string): string {
    return camelCase
      .replace(/([a-z])([A-Z])/g, '$1_$2') // Insert underscore between lowercase and uppercase letters
      .toUpperCase(); // Convert to uppercase
  }

export function generateEnvFile() {
    console.log('Generating env file...');
    const addressBook = loadAddressBook();
    let output = '';

    // Group contracts by type
    const factories: string[] = [];
    const actions: string[] = [];
    const rules: string[] = [];
    const primitives: string[] = [];
    const aux: string[] = [];
    const misc: string[] = [];
    for (const [contractName, info] of Object.entries(addressBook as AddressBook)) {
      if (!info.address) continue;

      const envVarName = camelToAllCaps(contractName);
      const line = `${envVarName}="${info.address}"`;

      switch (info.contractType) {
        case ContractType.Factory: // Using enum instead of magic numbers
          factories.push(line);
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
      }
    }

    // Build output string
    output += '# CONTRACTS\n';
    output += factories.join('\n');
    output += '\n\n';

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

    fs.writeFileSync('contracts.env', output);
  }
