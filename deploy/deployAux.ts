import {
  ContractType,
  loadAddressBook,
  saveContractToAddressBook,
  loadContractFromAddressBook,
} from './lensUtils';
import * as hre from 'hardhat';
import {
  getWallet,
  parseLensContractDeployedEventsFromReceipt,
  getAddressFromEvents,
  verifyPrimitive,
  deployContract,
} from './utils';
import { ethers, ZeroAddress } from 'ethers';

const metadataURI = 'https://ipfs.io/ipfs/QmZ';

export const emptySourceStamp = {
  source: ZeroAddress,
  originalMsgSender: ZeroAddress,
  validator: ZeroAddress,
  nonce: 0,
  deadline: 0,
  signature: '0x',
};

export interface AppInitialProperties {
  graph: string;
  feeds: string[];
  namespace: string;
  groups: string[];
  defaultFeed: string;
  signers: string[];
  paymaster: string;
  treasury: string;
}

export async function deployLensPrimitives() {
  const lensFactoryAddress = loadAddressBook()['LensFactory'].address;
  if (!lensFactoryAddress) {
    throw new Error('LensFactory not found in address book');
  }
  console.log(`Running script to interact with LensFactory at ${lensFactoryAddress}`);

  // Load compiled contract info
  const lensFactoryArtifact = await hre.artifacts.readArtifact('LensFactory');

  // Initialize contract instance for interaction
  const lensFactory = new ethers.Contract(
    lensFactoryAddress,
    lensFactoryArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  const account = await deployLensAccount(lensFactory);
  const feed = await deployLensFeed(lensFactory);
  const group = await deployLensGroup(lensFactory);
  const graph = await deployLensGraph(lensFactory);
  const namespace = await deployLensNamespace(lensFactory);

  const initialProperties: AppInitialProperties = {
    graph,
    feeds: [feed],
    namespace,
    groups: [group],
    defaultFeed: feed,
    signers: [],
    paymaster: getWallet().address,
    treasury: getWallet().address,
  };

  const app = await deployLensApp(lensFactory, initialProperties);
}

async function deployLensAccount(lensFactory: ethers.Contract): Promise<string> {
  const contractName = 'Account';
  const name = 'LensExampleAccount';
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${contractName} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await lensFactory.deployAccount(
    metadataURI,
    getWallet().address,
    [],
    [],
    emptySourceStamp,
    []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const accountAddress = getAddressFromEvents(events, contractName);

  // await verifyPrimitive('Account', accountAddress, [
  //   getWallet().address,
  //   metadataURI,
  //   [],
  //   [],
  //   emptySourceStamp,
  //   []
  // ]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Misc,
    address: accountAddress,
  });

  return accountAddress;
}

async function deployLensFeed(lensFactory: ethers.Contract): Promise<string> {
  const contractName = 'Feed';
  const name = 'LensGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await lensFactory.deployFeed(metadataURI, getWallet().address, [], [], []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive(contractName, primitiveAddress, [metadataURI, accessControlAddress]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

async function deployLensGroup(lensFactory: ethers.Contract): Promise<string> {
  const contractName = 'Group';
  const name = 'LensGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await lensFactory.deployGroup(metadataURI, getWallet().address, [], [], [], ZeroAddress, []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive(contractName, primitiveAddress, [metadataURI, accessControlAddress]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

async function deployLensGraph(lensFactory: ethers.Contract): Promise<string> {
  const contractName = 'Graph';
  const name = 'LensGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const transaction = await lensFactory.deployGraph(metadataURI, getWallet().address, [], [], []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive(contractName, primitiveAddress, [metadataURI, accessControlAddress]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

export async function deployLensNamespace(
  lensFactory: ethers.Contract,
  noVerify: Boolean = false
): Promise<string> {
  const contractName = 'Namespace';
  const name = 'LensGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  const namespace = 'lens';
  const nftName = 'nftName';
  const nftSymbol = 'nftSymbol';

  const transaction = await lensFactory.deployNamespace(
    namespace,
    metadataURI,
    getWallet().address,
    [],
    [],
    [],
    nftName,
    nftSymbol
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');
  // const lensUsernameTokenURIProviderAddress = getAddressFromEvents(
  //   events,
  //   'username-token-uri-provider'
  // );

  // await verifyPrimitive('Namespace', primitiveAddress, [
  //   namespace,
  //   metadataURI,
  //   accessControlAddress,
  //   nftName,
  //   nftSymbol,
  //   lensUsernameTokenURIProviderAddress,
  // ]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

export async function deployLensApp(
  lensFactory: ethers.Contract,
  initialProperties: AppInitialProperties
): Promise<string> {
  const contractName = 'App';
  const name = 'LensGlobal' + contractName;
  const existingContract = loadContractFromAddressBook(name);
  if (existingContract && existingContract.address) {
    console.log(`${name} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying ' + name);
  console.log('Using the following initial properties:');
  console.log(initialProperties);
  const transaction = await lensFactory.deployApp(
    metadataURI,
    false,
    getWallet().address,
    [],
    initialProperties,
    []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;

  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const primitiveAddress = getAddressFromEvents(events, contractName);
  // const accessControlAddress = getAddressFromEvents(events, 'access-control');

  // await verifyPrimitive('App', appAddress, [
  //   metadataURI,
  //   false,
  //   accessControlAddress,
  //   initialProperties,
  //   [],
  // ]);

  saveContractToAddressBook({
    name: name,
    contractName: contractName,
    contractType: ContractType.Primitive,
    address: primitiveAddress,
  });

  return primitiveAddress;
}

export async function deployLensAccessControl() {
  const contractName = 'OwnerAdminOnlyAccessControl';
  const existingContract = loadContractFromAddressBook(contractName);
  if (existingContract && existingContract.address) {
    console.log(`${contractName} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  console.log('Deploying Access Control');

  const accessControlFactoryAddress = loadContractFromAddressBook('AccessControlFactory')?.address;
  if (!accessControlFactoryAddress) {
    throw new Error('AccessControlFactory not found in address book');
  }

  const accessControlFactoryArtifact = await hre.artifacts.readArtifact('AccessControlFactory');

  const accessControlFactory = new ethers.Contract(
    accessControlFactoryAddress,
    accessControlFactoryArtifact.abi,
    getWallet()
  );

  const transaction = await accessControlFactory.deployOwnerAdminOnlyAccessControl(
    getWallet().address,
    []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const accessControlAddress = getAddressFromEvents(events, 'access-control');

  await verifyPrimitive('OwnerAdminOnlyAccessControl', accessControlAddress, [getWallet().address]);

  saveContractToAddressBook({
    contractName: 'OwnerAdminOnlyAccessControl',
    contractType: ContractType.Aux,
    address: accessControlAddress,
  });

  return accessControlAddress;
}

export async function deployLensActionHub(): Promise<string> {
  const contractName = 'ActionHub';
  const existingContract = loadContractFromAddressBook(contractName);
  if (existingContract && existingContract.address) {
    console.log(`${contractName} already deployed at ${existingContract.address}. Skipping...`);
    return existingContract.address;
  }

  // deploy action hub
  console.log('Deploying Action Hub...');
  const actionHub_artifactName = 'ActionHub';
  const actionHub_args: any[] = [];

  const actionHub = await deployContract(actionHub_artifactName, actionHub_args);

  const actionHubAddress = await actionHub.getAddress();

  saveContractToAddressBook({
    contractName: 'ActionHub',
    contractType: ContractType.Aux,
    address: actionHubAddress,
  });

  return actionHubAddress;
}
