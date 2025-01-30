import deployImplementations from './deployImplementations';
import deployFactories from './deployFactories';
import { deployLensPrimitives, deployLensAccessControl, deployLensActionHub } from './deployAux';
import { deployRules } from './deployRules';
import { deployActions } from './deployActions';
import { generateEnvFile } from './lensUtils';
import { deployBeacons, deployProxyAdminLock, deployAccessControlLock } from './deployProxyStuff';
import { getWallet, LOCAL_RICH_WALLETS } from './utils';

async function deploy() {
  const DEPLOYING_MIGRATION = Boolean(process.env.DEPLOY_MIGRATION);
  const DEPLOYING_FR = Boolean(process.env.DEPLOY_FR);
  const deployerAddress = getWallet().address;

  if (DEPLOYING_MIGRATION) {
    console.log('\x1b[33m=============================================')
    console.log('|                                           |');
    console.log('|       Deploying migration version         |');
    console.log('|                                           |');
    console.log('=============================================\x1b[0m')
  }

  const proxyAdminLockOwner = process.env.PROXY_ADMIN_LOCK_OWNER;
  if (!proxyAdminLockOwner && DEPLOYING_FR) {
    throw new Error('PROXY_ADMIN_LOCK_OWNER not found in environment variables');
  }

  const accessControlLockOwner = process.env.ACCESS_CONTROL_LOCK_OWNER;
  if (!accessControlLockOwner && DEPLOYING_FR) {
    throw new Error('ACCESS_CONTROL_LOCK_OWNER not found in environment variables');
  }

  const beaconOwner = process.env.BEACON_OWNER;
  if (!beaconOwner && DEPLOYING_FR) {
    throw new Error('BEACON_OWNER not found in environment variables');
  }

  const factoriesProxyOwner = process.env.FACTORIES_PROXY_OWNER;
  if (!factoriesProxyOwner && DEPLOYING_FR) {
    throw new Error('FACTORIES_PROXY_OWNER not found in environment variables');
  }

  const rulesOwner = process.env.RULES_OWNER;
  if (!rulesOwner && DEPLOYING_FR) {
    throw new Error('RULES_OWNER not found in environment variables');
  }

  const actionsOwner = process.env.ACTIONS_OWNER;
  if (!rulesOwner && DEPLOYING_FR) {
    throw new Error('ACTIONS_OWNER not found in environment variables');
  }

  if (DEPLOYING_FR) {
    console.log('ProxyAdminLockOwner', proxyAdminLockOwner);
    console.log('AccessControlAdminLockOwner', accessControlLockOwner);
    console.log('BeaconOwner', beaconOwner);
    console.log('FactoriesProxyOwner', factoriesProxyOwner);
    console.log('RulesOwner', rulesOwner);
  } else {
    console.log('\nNot Deploying fr, so using deployer address as owner everywhere:');
    console.log('\tProxyAdminLockOwner:', deployerAddress);
    console.log('\tBeaconOwner:', deployerAddress);
    console.log('\tFactoriesProxyOwner:', LOCAL_RICH_WALLETS[1].address); // Cannot be deployer cause later it will fail to execute the lensFactory primitives deployments
  }
  console.log('\n-------------------------------------------------------------------\n\n');

  await deployProxyAdminLock(proxyAdminLockOwner ?? deployerAddress);
  await deployAccessControlLock(accessControlLockOwner ?? deployerAddress);
  await deployImplementations(DEPLOYING_MIGRATION);
  await deployBeacons(beaconOwner ?? deployerAddress);
  await deployFactories(rulesOwner ?? deployerAddress, factoriesProxyOwner ?? LOCAL_RICH_WALLETS[1].address, DEPLOYING_MIGRATION);
  await deployLensPrimitives(DEPLOYING_MIGRATION);
  if (!DEPLOYING_MIGRATION) {
    const actionHub = await deployLensActionHub();
    await deployLensAccessControl();
    await deployRules(rulesOwner ?? deployerAddress);
    await deployActions(actionHub, actionsOwner ?? deployerAddress);
  }
  generateEnvFile();
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
