import {
    deployImplAndUpgradeTransparentProxy,
    ContractType,
    ContractInfo,
    loadContractAddressFromAddressBook,
    getTransparentUpgradeableProxyImplementationAddress,
    getContractBytecodeHashByAddress,
    getArtifactBytecodeHash,
    deployImplAndUpgradeBeacon,
    getBeaconImplementationAddress
  } from './lensUtils';
  import { getWallet } from './utils';

  async function deploy() {
    const proxyOwnerPrivateKey = process.env.PROXY_ADMIN_PRIVATE_KEY;
    if (!proxyOwnerPrivateKey) {
      throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
    }

    const proxyOwnerWallet = await getWallet(proxyOwnerPrivateKey);
    const proxyOwnerAddress = await proxyOwnerWallet.getAddress();

    console.log(`Using proxy owner private key with address: ${proxyOwnerAddress}`);

    //////////// SETUP ////////////

    const version = 10000; // 1.0.0

    const beaconsToUpgrade: ContractInfo[] = [
        {
            contractName: 'Account',
            contractType: ContractType.Beacon,
            constructorArguments: []
        }
    ]

    ///////////////////////////// TRANSPARENT UPGRADEABLE PROXY UPGRADES ///////////////////////////////////

    const upgradedBeacons: {name: string, beaconInfo: ContractInfo}[] = [];

    for (const beacon of beaconsToUpgrade) {
      const upgradedBeacon = await deployImplAndUpgradeBeacon(proxyOwnerWallet, beacon, version);
      upgradedBeacons.push(upgradedBeacon);
    }

    ///////////////////////////// VERIFICATION ///////////////////////////////////

    console.log('\n\n');
    console.log('//////////////////////////// VERIFICATION ///////////////////////////////////');

    if (upgradedBeacons.length !== beaconsToUpgrade.length) {
      throw new Error('Failed to upgrade all beacons');
    }

    for (const upgradedBeacon of upgradedBeacons) {
      const implementationOnchain = await getBeaconImplementationAddress(upgradedBeacon.beaconInfo.address!);
      const bytecodeHash = await getContractBytecodeHashByAddress(implementationOnchain);
      const artifactBytecodeHash = await getArtifactBytecodeHash(upgradedBeacon.name);
      if (bytecodeHash !== artifactBytecodeHash) {
        throw new Error(`${upgradedBeacon.name} bytecode hash mismatch: ${bytecodeHash} !== ${artifactBytecodeHash}`);
      } else {
        console.log(`\x1b[32m${upgradedBeacon.name} onchain bytecode hash verified: ${bytecodeHash} and matches artifact bytecode hash\x1b[0m`);
      }
    }
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
