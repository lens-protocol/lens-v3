import deployImplementations from './deployImplementations';
import deployFactories from './deployFactories';
import { deployLensPrimitives, deployLensAccessControl, deployLensActionHub } from './deployAux';
import { deployRules } from './deployRules';
import { deployActions } from './deployActions';
import { generateEnvFile, loadContractAddressFromAddressBook } from './lensUtils';
import { deployBeacons, deployProxyAdminLock } from './deployProxyStuff';
import { getWallet } from './utils';

export default async function deploy() {
  const DEPLOYING_FR = false;
  const deployerAddress = getWallet().address;

  const lockOwner = loadContractAddressFromAddressBook('ProxyAdminLockOwner');
  if (!lockOwner && DEPLOYING_FR) {
    throw new Error('ProxyAdminLockOwner not found in addressBook');
  }

  const beaconOwner = loadContractAddressFromAddressBook('BeaconOwner');
  if (!beaconOwner && DEPLOYING_FR) {
    throw new Error('BeaconOwner not found in addressBook');
  }

  if (DEPLOYING_FR) {
    console.log('ProxyAdminLockOwner', lockOwner);
    console.log('BeaconOwner', beaconOwner);
  } else {
    console.log('Not Deploying fr, so using deployer address as owner everywhere:');
    console.log('\tProxyAdminLockOwner:', deployerAddress);
    console.log('\tBeaconOwner:', deployerAddress);
  }

  await deployProxyAdminLock(lockOwner ?? deployerAddress);
  await deployImplementations();
  await deployBeacons(beaconOwner ?? deployerAddress);
  await deployFactories();
  await deployLensPrimitives();
  const actionHub = await deployLensActionHub();
  await deployLensAccessControl();
  await deployRules();
  await deployActions(actionHub);
  generateEnvFile();
}
