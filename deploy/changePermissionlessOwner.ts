import * as hre from 'hardhat';
import { getWallet } from './utils';
import { ethers } from 'ethers';

import * as fs from 'fs';

export default async function () {
  const contractArtifact = await hre.artifacts.readArtifact('ChangeAC');

  const apps = require('../apps.json').map((app: { app_address: string }) => app.app_address);
  console.log(`Loaded ${apps.length} apps`);

  const contract = new ethers.Contract(
    '0x69Ee67827F4f3f21FceFe696C58dB79DEA3105cD',
    contractArtifact.abi,
    getWallet()
  );

  for (let i = 0; i < apps.length; i += 50) {
    const batch = apps.slice(i, i + 50);
    console.log(`Processing batch ${i/50 + 1} of ${Math.ceil(apps.length/50)}`);
    const transaction = await contract.changeACs(
      batch,
      '0x9248090e86BCE5Ae1420B98751404D654C35cf0D'
    );
    await transaction.wait();
    console.log(`Completed batch ${i/50 + 1}`);
  }
}
