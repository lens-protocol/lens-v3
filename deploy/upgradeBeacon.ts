import {
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
  saveContractToAddressBook,
} from './lensUtils';
import { deployContract, getWallet } from './utils';
import * as hre from 'hardhat';
import { ethers, keccak256 } from 'ethers';

async function deploy() {
  const beaconOwnerPk = process.env.BEACON_OWNER_PRIVATE_KEY;
  if (!beaconOwnerPk) {
    throw new Error('BEACON_OWNER_PRIVATE_KEY not found in environment variables');
  }

  const beaconOwnerWallet = getWallet(beaconOwnerPk);

  const beaconOwner = await beaconOwnerWallet.getAddress();

  const beaconOwnerBalance = await beaconOwnerWallet.getBalance();
  if (beaconOwnerBalance < ethers.parseEther('0.01')) {
    throw new Error('Beacon owner balance is less than 0.01 ETH');
  }

  console.log(`Using Beacon owner private key with address: ${beaconOwner}`);
  console.log(`Beacon owner balance: ${ethers.formatEther(beaconOwnerBalance)}`);

  const beaconContractName = 'AccountBeacon';
  const beaconArtifact = await hre.artifacts.readArtifact('Beacon');
  const beaconAddress = await loadContractAddressFromAddressBook(beaconContractName);
  if (!beaconAddress) {
    throw new Error(`${beaconContractName} not found in address book`);
  } else {
    console.log(`${beaconContractName} address: ${beaconAddress}`);
  }

  const beacon = new hre.ethers.Contract(beaconAddress, beaconArtifact.abi, beaconOwnerWallet);

  const currentImpl = await beacon.implementation();

  console.log(`Current implementation in the ${beaconContractName}: ${currentImpl}`);

  const newImplContractName = 'Account';

  const newImplInfo: ContractInfo = {
    name: 'AccountImpl',
    contractName: newImplContractName,
    contractType: ContractType.Implementation,
    constructorArguments: [],
  };

  console.log(
    `${newImplContractName} bytecode hash = ${keccak256(
      (await hre.artifacts.readArtifact(newImplContractName)).bytecode
    )}`
  );

  const newImpl = await deployContract(newImplInfo.contractName, newImplInfo.constructorArguments);

  const newVersion = 2;
  const newImplAddress = await newImpl.getAddress();

  console.log(`${newImplInfo.contractName} implementation deployed at ${newImplAddress}`);

  console.log(
    `Setting implementation ${newImplAddress} for version ${newVersion} on the ${beaconContractName}`
  );

  await beacon.setImplementationForVersion(newVersion, newImplAddress);

  console.log('Impl set for version!');

  console.log(`Setting version ${newVersion} as default on the ${beaconContractName}`);

  await beacon.setDefaultVersion(newVersion);

  console.log('Default version set!');

  console.log(
    `Current implementation in the ${beaconContractName}: ${await beacon.implementation()}`
  );
}

if (require.main === module) {
  deploy()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export default deploy;
