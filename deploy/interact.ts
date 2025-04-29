import * as hre from 'hardhat';
import { getWallet } from './utils';
import { ethers, ZeroAddress } from 'ethers';

import * as fs from 'fs';

export default async function () {
  const contractArtifact = await hre.artifacts.readArtifact('LensFactory');


  const contract = new ethers.Contract(
    '0x1fa75D26819Ac733bf7B1C1B36C3F8aEF32d2Cc0',
    contractArtifact.abi,
    getWallet()
  );

  const transaction = await contract.deployAccount(
    'test',
    await getWallet().getAddress(),
    [],
    [],
    {
      source: ZeroAddress,
      originalMsgSender: ZeroAddress,
      validator: ZeroAddress,
      nonce: 0,
      deadline: 0,
      signature: '0x'
    },
    []
  );
  const tx = await transaction.wait();
  console.log(`Deployed account`);
  console.log(tx);

  const accountFactoryArtifact = await hre.artifacts.readArtifact('AccountFactory');
  const accountFactoryContract = new ethers.Contract(
      '0x26C7fd63B06deb4F9E4B5955D540767b9Ac7bbaa',
      accountFactoryArtifact.abi,
      getWallet()
    );

    // Search for the Lens_Account_Created log from the tx receipt
    const logs = tx.logs;
    const lensAccountCreatedLog = logs.find((log: any) => log.topics[0] === accountFactoryContract.interface.getEvent('Lens_Account_Created')?.topicHash);

    // Parse the log using typed logs
    const log = accountFactoryContract.interface.parseLog(lensAccountCreatedLog);
    const account = log?.args["account"];
    console.log(`Account: ${account}`);

    const accountArtifact = await hre.artifacts.readArtifact('Account');

    const accountContract = new ethers.Contract(
      account,
      accountArtifact.abi,
      getWallet()
    );

    // Get the account metadata
    const metadata = await accountContract.getMetadataURI();
    console.log(`Account Metadata: ${metadata}`);

    // Get the account owner
    const owner = await accountContract.owner();
    console.log(`Account Owner: ${owner}`);

    const beaconProxyArtifact = await hre.artifacts.readArtifact('contracts/core/upgradeability/BeaconProxy.sol:BeaconProxy');
    const beaconProxyContract = new ethers.Contract(
      account,
      beaconProxyArtifact.abi,
      getWallet()
    );

    // Get the beacon
    const beacon = await beaconProxyContract.proxy__getBeacon();
    console.log(`Beacon: ${beacon}`);

    // Get the implementation
    const implementation = await beaconProxyContract.proxy__getImplementation();
    console.log(`Implementation: ${implementation}`);

    // Get the beaconProxy proxyAdmin
    const proxyAdmin = await beaconProxyContract.proxy__getProxyAdmin();
    console.log(`ProxyAdmin: ${proxyAdmin}`);

    // Get the beaconProxy autoUpgrade
    const autoUpgrade = await beaconProxyContract.proxy__getAutoUpgrade();
    console.log(`AutoUpgrade: ${autoUpgrade}`);
}
