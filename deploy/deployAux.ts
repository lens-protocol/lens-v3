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
  nonce: 0,
  deadline: 0,
  signature: '0x',
};

export interface AppInitialProperties {
  graph: string;
  feeds: string[];
  username: string;
  groups: string[];
  defaultFeed: string;
  signers: string[];
  paymaster: string;
  treasury: string;
}

export default async function () {
  const lensFactoryAddress = '0x0D68809ccC9638CC8B15dA9F86B0249b4edDc60A';
  const accessControlFactoryAddress = '0xd3CF2F709d4338Ec5aa38B001a4996543B79fB95';

  await deployPrimitives(lensFactoryAddress);
  await deployAccessControl(accessControlFactoryAddress);
}

export async function deployPrimitives(lensFactoryAddress: string) {
  console.log(`Running script to interact with LensFactory at ${lensFactoryAddress}`);

  // Load compiled contract info
  const lensFactoryArtifact = await hre.artifacts.readArtifact('LensFactory');

  // Initialize contract instance for interaction
  const lensFactory = new ethers.Contract(
    lensFactoryAddress,
    lensFactoryArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  const account = await deployAccount(lensFactory);
  console.log(`Account deployed: ${account}`);
  const feed = await deployFeed(lensFactory);
  console.log(`Feed deployed: ${feed}`);
  const group = await deployGroup(lensFactory);
  console.log(`Group deployed: ${group}`);
  const graph = await deployGraph(lensFactory);
  console.log(`Graph deployed: ${graph}`);
  const username = await deployUsername(lensFactory);
  console.log(`Username deployed: ${username}`);

  const initialProperties: AppInitialProperties = {
    graph,
    feeds: [feed],
    username,
    groups: [group],
    defaultFeed: feed,
    signers: [],
    paymaster: getWallet().address,
    treasury: getWallet().address,
  };

  const app = await deployApp(lensFactory, initialProperties);
  console.log(`App deployed: ${app}`);
}

async function deployAccount(lensFactory: ethers.Contract): Promise<string> {
  console.log('Deploying Account');
  const transaction = await lensFactory.deployAccount(
    metadataURI,
    getWallet().address,
    [],
    [],
    emptySourceStamp
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const accountAddress = getAddressFromEvents(events, 'account');

  await verifyPrimitive('Account', accountAddress, [
    getWallet().address,
    metadataURI,
    [],
    [],
    emptySourceStamp,
  ]);

  return accountAddress;
}

async function deployFeed(lensFactory: ethers.Contract): Promise<string> {
  console.log('Deploying Feed');
  const transaction = await lensFactory.deployFeed(metadataURI, getWallet().address, [], [], []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const feedAddress = getAddressFromEvents(events, 'feed');
  const accessControlAddress = getAddressFromEvents(events, 'access-control');

  await verifyPrimitive('Feed', feedAddress, [metadataURI, accessControlAddress]);

  return feedAddress;
}

async function deployGroup(lensFactory: ethers.Contract): Promise<string> {
  console.log('Deploying Group');
  const transaction = await lensFactory.deployGroup(metadataURI, getWallet().address, [], [], []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const groupAddress = getAddressFromEvents(events, 'group');
  const accessControlAddress = getAddressFromEvents(events, 'access-control');

  await verifyPrimitive('Group', groupAddress, [metadataURI, accessControlAddress]);

  return groupAddress;
}

async function deployGraph(lensFactory: ethers.Contract): Promise<string> {
  console.log('Deploying Graph');
  const transaction = await lensFactory.deployGraph(metadataURI, getWallet().address, [], [], []);

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const graphAddress = getAddressFromEvents(events, 'graph');
  const accessControlAddress = getAddressFromEvents(events, 'access-control');

  await verifyPrimitive('Graph', graphAddress, [metadataURI, accessControlAddress]);

  return graphAddress;
}

export async function deployUsername(
  lensFactory: ethers.Contract,
  noVerify: boolean = false
): Promise<string> {
  console.log('Deploying Username');
  const namespace = 'lens';
  const nftName = 'nftName';
  const nftSymbol = 'nftSymbol';

  const transaction = await lensFactory.deployUsername(
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
  const usernameAddress = getAddressFromEvents(events, 'username');
  const accessControlAddress = getAddressFromEvents(events, 'access-control');
  const lensUsernameTokenURIProviderAddress = getAddressFromEvents(
    events,
    'username-token-uri-provider'
  );

  if (!noVerify) {
    await verifyPrimitive('Username', usernameAddress, [
      namespace,
      metadataURI,
      accessControlAddress,
      nftName,
      nftSymbol,
      lensUsernameTokenURIProviderAddress,
    ]);
  }

  return usernameAddress;
}

export async function deployApp(
  lensFactory: ethers.Contract,
  initialProperties: AppInitialProperties
): Promise<string> {
  console.log('Deploying App');
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
  const appAddress = getAddressFromEvents(events, 'app');
  const accessControlAddress = getAddressFromEvents(events, 'access-control');

  await verifyPrimitive('App', appAddress, [
    metadataURI,
    false,
    accessControlAddress,
    initialProperties,
    [],
  ]);

  return appAddress;
}

export async function deployAccessControl(accessControlFactoryAddress: string) {
  console.log('Deploying Access Control');
  const accessControlFactoryArtifact = await hre.artifacts.readArtifact('AccessControlFactory');

  const accessControlFactory = new ethers.Contract(
    accessControlFactoryAddress,
    accessControlFactoryArtifact.abi,
    getWallet()
  );

  const transaction = await accessControlFactory.deployOwnerAdminOnlyAccessControl(
    getWallet().address, []
  );

  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;
  const events = parseLensContractDeployedEventsFromReceipt(txReceipt);
  const accessControlAddress = getAddressFromEvents(events, 'access-control');

  await verifyPrimitive('OwnerAdminOnlyAccessControl', accessControlAddress, [getWallet().address]);

  return accessControlAddress;
}
