import * as hre from 'hardhat';
import { getWallet, verifyContract } from './utils';
import { ethers } from 'ethers';
import { Deployer } from '@matterlabs/hardhat-zksync';

export default async function () {
  const LENS_FACTORY_ADDRESS = '0x0eC869F765b4ec67982Df66b4ffbA6b00F462661';

  console.log(`Running script to interact with LensFactory at ${LENS_FACTORY_ADDRESS}`);

  // Load compiled contract info
  const lensFactoryArtifact = await hre.artifacts.readArtifact('LensFactory');

  // Initialize contract instance for interaction
  const lensFactory = new ethers.Contract(
    LENS_FACTORY_ADDRESS,
    lensFactoryArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  const metadataURI = 'https://ipfs.io/ipfs/QmZ';
  const ownerAddress = getWallet().address;
  const admins: string[] = [];
  const rules: any[] = [];
  const extraData: any[] = [];

  // Run contract write function
  const transaction = await lensFactory.deployFeed(
    metadataURI,
    ownerAddress,
    admins,
    rules,
    extraData
  );

  console.log(`Transaction hash of deploying new Feed Primitive: ${transaction.hash}`);

  // Wait until transaction is processed
  const txReceipt = (await transaction.wait()) as ethers.TransactionReceipt;

  const eventInterface = new ethers.Interface([
    'event Lens_Contract_Deployed(string indexed indexedContractType, string indexed indexedFlavour, string contractType, string flavour)',
  ]);

  // Parse event logs
  const events = txReceipt.logs.map((log) => {
    try {
      // console.log('Log:', log);
      const decodedLog = eventInterface.decodeEventLog(
        'Lens_Contract_Deployed',
        log.data,
        log.topics
      );
      // console.log(log.address);
      // console.log(decodedLog);
      return { primitive: decodedLog[2], primitiveType: decodedLog[3], address: log.address };
    } catch (e) {
      return null;
    }
  });

  // console.log('Events:', events);

  const feedPrimitiveAddress = events.filter((e) => e?.primitive === 'feed')[0]!.address;
  const accessControlAddress = events.filter((e) => e?.primitive === 'access-control')[0]!.address;

  console.log('Feed Primitive Address:', feedPrimitiveAddress);
  console.log('Access Control Address:', accessControlAddress);

  // Load compiled contract info
  const feedArtifact = await hre.artifacts.readArtifact('Feed');

  const deployer = new Deployer(hre, getWallet());
  const artifact = await deployer.loadArtifact('Feed');

  // Initialize contract instance for interaction
  const feed = new ethers.Contract(
    feedPrimitiveAddress,
    feedArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  const constructorArgs = feed.interface.encodeDeploy([metadataURI, accessControlAddress]);
  const fullContractSource = `${artifact.sourceName}:${artifact.contractName}`;

  await verifyContract({
    address: feedPrimitiveAddress,
    contract: fullContractSource,
    constructorArguments: constructorArgs,
    bytecode: artifact.bytecode,
  });
}
