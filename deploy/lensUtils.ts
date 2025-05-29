import fs from 'fs';
import { deployContract, getProvider, getWallet } from './utils';
import { keccak256, toUtf8Bytes, Wallet } from 'ethers';
import * as hre from 'hardhat';
import { ethers } from 'hardhat';

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
  proxyAdmin?: string;
  initializerCalldata?: string;
  owner?: string;
  metadataURI?: string;
  lensCreate2PreSalt?: string;
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

export async function deployLensContract(
  contractToDeploy: ContractInfo,
  override: Boolean = false
) {
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
  proxyOwner: string,
  initializerCalldata?: string
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

  const constructorArguments = [
    await deployedImplementation.getAddress(),
    proxyOwner,
    initializerCalldata ?? '0x',
  ];
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

  if (initializerCalldata) {
    proxyInfo.initializerCalldata = initializerCalldata;
  }

  addressBook[name] = proxyInfo;
  saveAddressBook(addressBook);

  return {
    name: contractToDeploy.name,
    ...proxyInfo,
  };
}

export async function deployImplAndUpgradeTransparentProxy(
  proxyAdminWallet: Wallet,
  contractToUpgrade: ContractInfo,
  contractSolidityName?: string
) {
  const addressBook = loadAddressBook();
  const nameWithImplSuffix = contractToUpgrade.name ?? contractToUpgrade.contractName + 'Impl';

  // Checking the bytecode of current implementation in the proxy
  const proxyOnAddressBook = addressBook[contractToUpgrade.contractName];
  const proxyAddress = proxyOnAddressBook.address;

  if (!proxyAddress) {
    throw new Error(`Proxy for ${contractToUpgrade.contractName} not found in address book`);
  } else {
    console.log(
      `We will upgrade the ${contractToUpgrade.contractName}'s proxy located at ${proxyAddress}`
    );
  }
  console.log('\n\n');

  const proxyAdminOnchain = await hre.upgrades.erc1967.getAdminAddress(proxyAddress);

  if (proxyAdminOnchain !== (await proxyAdminWallet.getAddress())) {
    throw new Error(
      `Proxy admin (${proxyAdminOnchain}) in the contract on-chain is not the proxy owner derived from private key: ${await proxyAdminWallet.getAddress()}`
    );
  }

  const artifact = await hre.artifacts.readArtifact(contractSolidityName ?? contractToUpgrade.contractName);
  const bytecodeHash = calculateBytecodeHash(artifact.bytecode);

  const implOnAddressBook = addressBook[nameWithImplSuffix];
  const bytecodeHashOnAddressBook = implOnAddressBook?.bytecodeHash ?? undefined;

  if (!implOnAddressBook || bytecodeHashOnAddressBook !== bytecodeHash) {
    console.log(`Deploying ${nameWithImplSuffix}...`);

    const deployedImplementation = await deployContract(
      contractSolidityName ?? contractToUpgrade.contractName,
      contractToUpgrade.constructorArguments
    );


    addressBook[nameWithImplSuffix] = {
      contractName: contractSolidityName ?? contractToUpgrade.contractName,
      contractType: ContractType.Implementation,
      address: await deployedImplementation.getAddress(),
      bytecodeHash,
      constructorArguments: contractToUpgrade.constructorArguments,
    };
    saveAddressBook(addressBook);
    console.log(`\x1b[32m${nameWithImplSuffix} deployed at ${await deployedImplementation.getAddress()}\x1b[0m`);
  } else {
    console.log(`\x1b[36m${nameWithImplSuffix} already deployed at ${implOnAddressBook.address} with matching bytecode hash ${implOnAddressBook.bytecodeHash}. Skipping...\x1b[0m`);
  }

  const deployedImpl: ContractInfo = addressBook[nameWithImplSuffix];
  const implementationAddress = deployedImpl.address!;

  const beforeImplementation = await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);
  const implBytecodeHashOnchain = calculateBytecodeHash(await hre.ethers.provider.getCode(beforeImplementation));

  const transparentUpgradeableProxyArtifact = await hre.artifacts.readArtifact(
    'ITransparentUpgradeableProxy'
  );
  const transparentUpgradeableProxy = new ethers.Contract(
    proxyAddress,
    transparentUpgradeableProxyArtifact.abi,
    proxyAdminWallet
  );

  console.log('\n\n');

  if (implBytecodeHashOnchain !== bytecodeHash) {
    console.log(`Old implementation in the Proxy: ${beforeImplementation}`);
    console.log(`Upgrading ${contractToUpgrade.contractName}'s proxy to new implementation...`);
    const upgradeTx = await transparentUpgradeableProxy.upgradeTo(implementationAddress);
    await upgradeTx.wait();
    console.log(`Upgrade complete!`);

    const upgradedImplementation = await hre.upgrades.erc1967.getImplementationAddress(
      proxyAddress
    );
    if (upgradedImplementation !== implementationAddress) {
      throw new Error(`${contractToUpgrade.contractName} upgrade failed. Implementation mismatch: ${upgradedImplementation} !== ${implementationAddress}`);
    }

    proxyOnAddressBook.implementation = deployedImpl.address;

    const proxyBytecodeHashOnchain = calculateBytecodeHash(await hre.ethers.provider.getCode(proxyAddress));
    proxyOnAddressBook.bytecodeHash = proxyBytecodeHashOnchain;

    addressBook[contractToUpgrade.contractName] = proxyOnAddressBook;
    saveAddressBook(addressBook);
    console.log(`\x1b[32mProxy for ${contractToUpgrade.contractName} upgraded to ${deployedImpl.address}\x1b[0m`);
    console.log('\n\n');
  } else {
    console.log(`\x1b[36m${contractToUpgrade.contractName} proxy already upgraded to new implementation with matching bytecode hash ${implBytecodeHashOnchain}\x1b[0m`);
  }

  return addressBook[contractToUpgrade.contractName];
}

export async function deployImplAndUpgradeBeacon(
  beaconOwnerWallet: Wallet,
  contractToUpgrade: ContractInfo,
  versionToSet: number
) {
  const addressBook = loadAddressBook();
  const nameWithImplSuffix = contractToUpgrade.contractName + 'Impl';
  const beaconName = contractToUpgrade.contractName + 'Beacon';

  // Checking the bytecode of current implementation in the beacon
  const beaconOnAddressBook = addressBook[beaconName];
  const beaconAddress = beaconOnAddressBook.address;

  if (!beaconAddress) {
    throw new Error(`${beaconName} not found in address book`);
  }
  console.log('\n\n');

  const beaconArtifact = await hre.artifacts.readArtifact("Beacon");
  const beaconAbi = beaconArtifact.abi;
  const beaconContract = new ethers.Contract(beaconAddress, beaconAbi, beaconOwnerWallet);

  const beaconOwnerOnchain = await beaconContract.owner();

  if (beaconOwnerOnchain !== (await beaconOwnerWallet.getAddress())) {
    throw new Error(
      `${beaconName} owner (${beaconOwnerOnchain}) on-chain doesn't match the beacon owner derived from private key: ${await beaconOwnerWallet.getAddress()}`
    );
  }

  const artifact = await hre.artifacts.readArtifact(contractToUpgrade.contractName);
  const bytecodeHash = calculateBytecodeHash(artifact.bytecode);

  const implOnAddressBook = addressBook[nameWithImplSuffix];
  const bytecodeHashOnAddressBook = implOnAddressBook?.bytecodeHash ?? undefined;

  if (!implOnAddressBook || bytecodeHashOnAddressBook !== bytecodeHash) {
    console.log(`Deploying ${nameWithImplSuffix}...`);

    const deployedImplementation = await deployContract(
      contractToUpgrade.contractName,
      contractToUpgrade.constructorArguments
    );


    addressBook[nameWithImplSuffix] = {
      contractName: contractToUpgrade.contractName,
      contractType: ContractType.Implementation,
      address: await deployedImplementation.getAddress(),
      bytecodeHash,
      constructorArguments: contractToUpgrade.constructorArguments,
    };
    saveAddressBook(addressBook);
    console.log(`\x1b[32m${nameWithImplSuffix} deployed at ${await deployedImplementation.getAddress()}\x1b[0m`);
  } else {
    console.log(`\x1b[36m${nameWithImplSuffix} already deployed at ${implOnAddressBook.address} with matching bytecode hash ${implOnAddressBook.bytecodeHash}. Skipping...\x1b[0m`);
  }

  const deployedImpl: ContractInfo = addressBook[nameWithImplSuffix];
  const implementationAddress = deployedImpl.address!;

  const beforeImplementation = await beaconContract.implementation();
  const implBytecodeHashOnchain = await getContractBytecodeHashByAddress(beforeImplementation);

  console.log('\n\n');

  if (implBytecodeHashOnchain !== bytecodeHash) {
    console.log(`Old implementation in the Beacon: ${beforeImplementation}`);

    // As there is no getter, we read Default Version Storage Slot 1
    const beaconDefaultVersionBytes = await getProvider().getStorage(beaconAddress, 1);
    const beaconDefaultVersion = ethers.toNumber(beaconDefaultVersionBytes);
    console.log(`Beacon contract current default version: ${beaconDefaultVersion}`);

    console.log(`Setting new implementation ${implementationAddress} for version ${versionToSet}`);
    if (beaconDefaultVersion == versionToSet) {
      console.log('...overwriting implementation for the current default version');
    }

    const beaconUpgradeTx = await beaconContract.setImplementationForVersion(versionToSet, implementationAddress);
    await beaconUpgradeTx.wait();

    if (beaconDefaultVersion !== versionToSet) {
      const beaconSetDefaultVersionTx = await beaconContract.setDefaultVersion(versionToSet);
      await beaconSetDefaultVersionTx.wait();
    }

    const beaconDefaultVersionAfterBytes = await getProvider().getStorage(beaconAddress, 1);
    const beaconDefaultVersionAfter = ethers.toNumber(beaconDefaultVersionAfterBytes);

    const beaconContractImplementationAfter = await beaconContract.implementation();

    if (beaconContractImplementationAfter !== implementationAddress) {
      throw new Error(`Beacon contract implementation after upgrade ${beaconContractImplementationAfter} is not the new implementation ${implementationAddress}`  );
    }
    console.log(`Beacon contract upgraded to implementation ${implementationAddress}`);

    if (beaconDefaultVersionAfter !== versionToSet) {
      throw new Error(`Beacon contract default version after upgrade ${beaconDefaultVersionAfter} is not the new version ${versionToSet}`);
    }

    if (beaconDefaultVersion !== beaconDefaultVersionAfter) {
      console.log(`Beacon contract DefaultVersion was set to ${beaconDefaultVersionAfter}`);
    } else {
      console.log(`Beacon contract DefaultVersion didn't change and is still set to ${beaconDefaultVersionAfter}`);
    }

    beaconOnAddressBook.implementation = deployedImpl.address;

    const beaconBytecodeHashOnchain = calculateBytecodeHash(await hre.ethers.provider.getCode(beaconAddress));
    beaconOnAddressBook.bytecodeHash = beaconBytecodeHashOnchain;

    addressBook[beaconName] = beaconOnAddressBook;
    saveAddressBook(addressBook);
    console.log(`\x1b[32m${beaconName} upgraded to ${deployedImpl.address}\x1b[0m`);
    console.log('\n\n');
  } else {
    console.log(`\x1b[36m${beaconName} already has the new implementation set with matching bytecodeHash ${implBytecodeHashOnchain}\x1b[0m`);
  }

  return {name: contractToUpgrade.contractName, beaconInfo: addressBook[beaconName]};
}

export async function deployLensContractWithCreate2(
  contractToDeploy: ContractInfo,
  proxyAdminAddress: string,
  initializerCalldata?: string
): Promise<ContractInfo> {
  const lensCreate2OwnerPk = process.env.LENS_CREATE2_OWNER_PRIVATE_KEY;
  if (!lensCreate2OwnerPk) {
    throw new Error('LENS_CREATE2_OWNER_PRIVATE_KEY not found in environment variables');
  }

  const lensCreate2OwnerBalance = await getWallet(lensCreate2OwnerPk).getBalance();
  if (lensCreate2OwnerBalance < ethers.parseEther('0.01')) {
    throw new Error('LensCreate2 Owner balance is less than 0.01 ETH');
  }

  console.log(
    `Using lensCreate2 owner private key with address: ${await getWallet(
      lensCreate2OwnerPk
    ).getAddress()}`
  );
  console.log(`LensCreate2 owner balance: ${ethers.formatEther(lensCreate2OwnerBalance)}`);

  const lensCreate2OwnerWallet = getWallet(lensCreate2OwnerPk);

  const lensCreate2Address = '0x52AF9CF29976C310E3DE03C509E108edB6edb8c0';
  const lensCreate2ContractName = 'LensCreate2';
  const lensCreate2Artifact = await hre.artifacts.readArtifact(lensCreate2ContractName);

  const lensCreate2 = new hre.ethers.Contract(
    lensCreate2Address,
    lensCreate2Artifact.abi,
    lensCreate2OwnerWallet
  );

  const onchainOwner = await lensCreate2.owner();
  if (lensCreate2OwnerWallet.address !== onchainOwner) {
    throw new Error(`LensCreate2 owner mismatch: Assume ${lensCreate2OwnerWallet.address} !== Onchain ${onchainOwner}`);
  }

  const nameWithImplSuffix = contractToDeploy.name ?? contractToDeploy.contractName + 'Impl';

  const addressBook = loadAddressBook();
  const artifact = await hre.artifacts.readArtifact(contractToDeploy.contractName);
  const bytecodeHash = calculateBytecodeHash(artifact.bytecode);

  ////////// Deploying implementation

  if (!addressBook[nameWithImplSuffix]) {
    console.log(`Deploying ${nameWithImplSuffix}...`);
    const deployedImplementation = await deployContract(
      contractToDeploy.contractName,
      contractToDeploy.constructorArguments
    );

    const deployedAddress = await deployedImplementation.getAddress();

    console.log(`\x1b[36m${nameWithImplSuffix} deployed at ${deployedAddress}\x1b[0m`);
    console.log(`Constructor arguments for implementation:`);
    console.table(contractToDeploy.constructorArguments);

    addressBook[nameWithImplSuffix] = {
      contractName: contractToDeploy.contractName,
      contractType: ContractType.Implementation,
      address: deployedAddress,
      bytecodeHash,
      constructorArguments: contractToDeploy.constructorArguments,
    };
    saveAddressBook(addressBook);
  } else {
    console.log(`\x1b[95m${nameWithImplSuffix} already deployed at ${addressBook[nameWithImplSuffix].address}. Skipping...\x1b[0m`);
  }

  const deployedImpl: ContractInfo = addressBook[nameWithImplSuffix];
  const implementationAddress = deployedImpl.address!;

  ////////// Deploying with LensCreate2

  const proxyArtifact = await hre.artifacts.readArtifact("TransparentUpgradeableProxy");
  const proxyBytecodeHash = calculateBytecodeHash(proxyArtifact.bytecode);

  if (!addressBook[contractToDeploy.contractName]) {
    const preSalt = 'lens.contract.' + contractToDeploy.contractName;
    const salt = keccak256(toUtf8Bytes(preSalt));
    const predictedAddress = await lensCreate2['getAddress(bytes32)'].staticCall(salt);
    console.log(`About to deploy contract for '${preSalt}'`);
    console.log(`Computed salt for '${preSalt}' is ${salt}`);
    console.log(`Predicted address for '${preSalt}' contract is ${predictedAddress}`);

    const implBytecodeHash = calculateBytecodeHash(
      (await hre.artifacts.readArtifact(contractToDeploy.contractName)).bytecode
    );
    const implBytecodeHashOnchain = calculateBytecodeHash(await hre.ethers.provider.getCode(implementationAddress));

    if (implBytecodeHash !== implBytecodeHashOnchain) {
      throw new Error(`${nameWithImplSuffix} bytecode hash mismatch: ${implBytecodeHash} !== ${implBytecodeHashOnchain}`);
    }

    console.log(`${nameWithImplSuffix} bytecode hash: ${implBytecodeHash}`);

    console.log(`Deploying ${contractToDeploy.contractName} proxy through LensCreate2`);

    const deployWithCreate2Tx = await lensCreate2.createTransparentUpgradeableProxy(
      salt,
      implementationAddress,
      proxyAdminAddress,
      initializerCalldata ?? '0x',
      predictedAddress
    );

    if (initializerCalldata !== undefined) {
      console.log(`Initializer was called with the following Calldata:\n${initializerCalldata}`);
    }

    await deployWithCreate2Tx.wait();

    console.log(`\x1b[32m${contractToDeploy.contractName} deployed at ${predictedAddress}\x1b[0m`);

    const proxyInfo: ContractInfo = {
      name: contractToDeploy.contractName,
      contractName: contractToDeploy.contractName,
      contractType: contractToDeploy.contractType,
      address: predictedAddress,
      bytecodeHash: proxyBytecodeHash,
      implementation: implementationAddress,
      proxyAdmin: proxyAdminAddress,
      lensCreate2PreSalt: preSalt,
    };

    if (initializerCalldata) {
      proxyInfo.initializerCalldata = initializerCalldata;
    }

    addressBook[contractToDeploy.contractName] = proxyInfo;
    saveAddressBook(addressBook);
  } else {
    console.log(`\x1b[95m${contractToDeploy.contractName} already deployed at ${addressBook[contractToDeploy.contractName].address}. Skipping...\x1b[0m`);
  }

  const proxyAddress = addressBook[contractToDeploy.contractName].address!;

  const proxyBytecodeHashOnchain = calculateBytecodeHash(await hre.ethers.provider.getCode(proxyAddress));
  if (proxyBytecodeHash !== proxyBytecodeHashOnchain) {
    throw new Error(`${contractToDeploy.contractName} proxy bytecode hash mismatch: ${proxyBytecodeHash} !== ${proxyBytecodeHashOnchain}`);
  }

  const proxyImplementationOnchain = await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);
  if (proxyImplementationOnchain !== implementationAddress) {
    throw new Error(`${contractToDeploy.contractName} proxy implementation mismatch: ${proxyImplementationOnchain} !== ${implementationAddress}`);
  }

  const proxyAdminOnchain = await hre.upgrades.erc1967.getAdminAddress(proxyAddress);
  if (proxyAdminOnchain !== proxyAdminAddress) {
    throw new Error(`${contractToDeploy.contractName} proxy admin mismatch: ${proxyAdminOnchain} !== ${proxyAdminAddress}`);
  }

  return addressBook[contractToDeploy.contractName];
}

export async function getTransparentUpgradeableProxyImplementationAddress(proxyAddress: string) {
  const proxyImplementationOnchain = await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);
  return proxyImplementationOnchain;
}

export async function getTransparentUpgradeableProxyAdminAddress(proxyAddress: string) {
  const proxyAdminOnchain = await hre.upgrades.erc1967.getAdminAddress(proxyAddress);
  return proxyAdminOnchain;
}

export async function getBeaconImplementationAddress(beaconAddress: string) {
  const beaconArtifact = await hre.artifacts.readArtifact("Beacon");
  const beaconAbi = beaconArtifact.abi;
  const beaconContract = new ethers.Contract(beaconAddress, beaconAbi, await getWallet());
  const implementationAddress = await beaconContract.implementation();
  return implementationAddress;
}

export async function getContractBytecodeHashByAddress(contractAddress: string) {
  const bytecodeHash = calculateBytecodeHash(await hre.ethers.provider.getCode(contractAddress));
  return bytecodeHash;
}

export async function getArtifactBytecodeHash(artifactName: string) {
  const artifact = await hre.artifacts.readArtifact(artifactName);
  return calculateBytecodeHash(artifact.bytecode);
}

export function getInitializeEncodedCall(owner: string, metadataURI?: string) {
  if (metadataURI !== undefined) {
    const initializerABI = ['function initialize(address owner, string memory metadataURI) external'];
    const initializerInterface = new ethers.Interface(initializerABI);
    const initializeEncodedCall = initializerInterface.encodeFunctionData('initialize', [
      owner,
      metadataURI,
    ]);
    return initializeEncodedCall;
  } else {
    const initializerABI = ['function initialize(address owner) external'];
    const initializerInterface = new ethers.Interface(initializerABI);
    const initializeEncodedCall = initializerInterface.encodeFunctionData('initialize', [
      owner,
    ]);
    return initializeEncodedCall;
  }
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
