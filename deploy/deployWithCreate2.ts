import {
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
  saveContractToAddressBook,
} from './lensUtils';
import { deployContract, getWallet } from './utils';
import * as hre from 'hardhat';
import { ethers, keccak256, toUtf8Bytes } from 'ethers';

async function deploy() {
  /////////////////// SETUP ///////////////////

  const preSalt = 'lens.contract.LensFees';

  const implToDeploy: ContractInfo = {
    name: 'LensFeesImpl',
    contractName: 'LensFees',
    contractType: ContractType.Implementation,
    constructorArguments: [process.env.TREASURY_ADDRESS, process.env.TREASURY_FEE_BPS],
  };

  // const initializerABI = ['function initialize(address owner) external'];
  // const initializerInterface = new ethers.Interface(initializerABI);
  // const initializeEncodedCall = initializerInterface.encodeFunctionData('initialize', [
  //   '0x5FCD072a0BD58B6fa413031582E450FE724dba6D',
  // ]);

  const initializeEncodedCall = '0x';

  /////////////////////////////////////////////

  const proxyAdminPk = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!proxyAdminPk) {
    throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
  }

  const proxyAdminBalance = await getWallet(proxyAdminPk).getBalance();
  if (proxyAdminBalance < ethers.parseEther('0.01')) {
    throw new Error('Proxy admin balance is less than 0.01 ETH');
  }

  const proxyAdminAddress = await getWallet(proxyAdminPk).getAddress();

  console.log(`Using proxy admin private key with address: ${proxyAdminAddress}`);
  console.log(`Proxy admin balance: ${ethers.formatEther(proxyAdminBalance)}`);

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

  const salt = keccak256(toUtf8Bytes(preSalt));

  const lensCreate2Address = '0x52AF9CF29976C310E3DE03C509E108edB6edb8c0';
  const lensCreate2ContractName = 'LensCreate2';
  const lensCreate2Artifact = await hre.artifacts.readArtifact(lensCreate2ContractName);

  const lensCreate2 = new hre.ethers.Contract(
    lensCreate2Address,
    lensCreate2Artifact.abi,
    lensCreate2OwnerWallet
  );

  const predictedAddress = await lensCreate2['getAddress(bytes32)'].staticCall(salt);

  console.log(`About to deploy contract for '${preSalt}'`);
  console.log(`Computed salt for '${preSalt}' is ${salt}`);
  console.log(`Predicted address for '${preSalt}' contract is ${predictedAddress}`);
  console.log(
    `Deploying '${implToDeploy.name}' implementation for '${implToDeploy.contractName} contract'`
  );
  console.log(`Constructor arguments for implementation: ${implToDeploy.constructorArguments}`);
  const implBytecodeHash = keccak256(
    (await hre.artifacts.readArtifact(implToDeploy.contractName)).bytecode
  );
  console.log(`${implToDeploy.name} bytecode hash: ${implBytecodeHash}`);

  const implementationDeployed = await deployContract(
    implToDeploy.contractName,
    implToDeploy.constructorArguments
  );
  const implementationAddress = await implementationDeployed.getAddress();

  console.log(`${implToDeploy.contractName} implementation deployed at ${implementationAddress}`);

  console.log(`Deploying ${implToDeploy.contractName} proxy through LensCreate2`);

  const deployWithCreate2Tx = await lensCreate2.createTransparentUpgradeableProxy(
    salt,
    implementationAddress,
    proxyAdminAddress,
    initializeEncodedCall,
    predictedAddress
  );

  await deployWithCreate2Tx.wait();

  console.log(`Contract deployment tx mined!`);

  console.log(`You might want to copy this into the addressBook ;)`);

  const output = {
    address: predictedAddress,
    bytecodeHash: implBytecodeHash,
  };

  console.log(output);
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
