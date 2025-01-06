import deployImplementations from './deployImplementations';
import deployFactories from './deployFactories';
import { deployLensPrimitives, deployLensAccessControl, deployLensActionHub } from './deployAux';
import { deployRules } from './deployRules';
import { deployActions } from './deployActions';
import { generateEnvFile } from './lensUtils';
import { deployBeacons, deployProxyAdminLock } from './deployProxyStuff';
import { getWallet, LOCAL_RICH_WALLETS } from './utils';

export default async function deploy() {
  const DEPLOYING_FR = false;
  const deployerAddress = getWallet().address;

  const lockOwner = process.env.PROXY_ADMIN_LOCK_OWNER;
  if (!lockOwner && DEPLOYING_FR) {
    throw new Error('PROXY_ADMIN_LOCK_OWNER not found in environment variables');
  }

  const beaconOwner = process.env.BEACON_OWNER;
  if (!beaconOwner && DEPLOYING_FR) {
    throw new Error('BEACON_OWNER not found in environment variables');
  }

  const factoriesProxyOwner = process.env.FACTORIES_PROXY_OWNER;
  if (!factoriesProxyOwner && DEPLOYING_FR) {
    throw new Error('FACTORIES_PROXY_OWNER not found in environment variables');
  }

  if (DEPLOYING_FR) {
    console.log('ProxyAdminLockOwner', lockOwner);
    console.log('BeaconOwner', beaconOwner);
    console.log('FactoriesProxyOwner', factoriesProxyOwner);
  } else {
    console.log('Not Deploying fr, so using deployer address as owner everywhere:');
    console.log('\tProxyAdminLockOwner:', deployerAddress);
    console.log('\tBeaconOwner:', deployerAddress);
    console.log('\tFactoriesProxyOwner:', LOCAL_RICH_WALLETS[1].address); // Cannot be deployer cause later it will fail to execute the lensFactory primitives deployments
  }

  await deployProxyAdminLock(lockOwner ?? deployerAddress);
  await deployImplementations();
  await deployBeacons(beaconOwner ?? deployerAddress);
  await deployFactories(factoriesProxyOwner ?? LOCAL_RICH_WALLETS[1].address);
  await deployLensPrimitives();
  const actionHub = await deployLensActionHub();
  await deployLensAccessControl();
  await deployRules();
  await deployActions(actionHub);
  generateEnvFile();
}
