import deployImplementations from './deployImplementations';
import deployFactories from './deployFactories';
import { deployLensPrimitives, deployLensAccessControl, deployLensActionHub } from './deployAux';
import { deployRules } from './deployRules';
import { deployActions } from './deployActions';
import { generateEnvFile } from './lensUtils';
import { deployBeacons, deployLock } from './deployProxyStuff';
import { getWallet, LOCAL_RICH_WALLETS } from './utils';

async function deploy() {
  const DEPLOYING_MIGRATION = Boolean(process.env.DEPLOY_MIGRATION);
  const DEPLOYING_FR = Boolean(process.env.DEPLOY_FR);
  const deployerAddress = getWallet().address;

  if (DEPLOYING_MIGRATION) {
    console.log('\x1b[33m=============================================');
    console.log('|                                           |');
    console.log('|       Deploying migration version         |');
    console.log('|                                           |');
    console.log('=============================================\x1b[0m');
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

  const primitivesOwner = process.env.PRIMITIVES_OWNER;
  if (!primitivesOwner && DEPLOYING_FR) {
    throw new Error('PRIMITIVES_OWNER not found in environment variables');
  }

  const treasuryAddress = process.env.TREASURY_ADDRESS;
  if (!treasuryAddress && DEPLOYING_FR) {
    throw new Error('TREASURY_ADDRESS not found in environment variables');
  }

  const treasuryFeeBps = Number(process.env.TREASURY_FEE_BPS);
  if (isNaN(treasuryFeeBps) && DEPLOYING_FR) {
    console.error(`treasuryFeeBps: ${treasuryFeeBps}`);
    throw new Error('TREASURY_FEE_BPS not found in environment variables or is not a valid number');
  }

  if (DEPLOYING_FR) {
    console.log('ProxyAdminLockOwner', proxyAdminLockOwner);
    console.log('AccessControlAdminLockOwner', accessControlLockOwner);
    console.log('BeaconOwner', beaconOwner);
    console.log('FactoriesProxyOwner', factoriesProxyOwner);
    console.log('RulesOwner', rulesOwner);
    console.log('ActionsOwner', actionsOwner);
    console.log('PrimitivesOwner', primitivesOwner);
  } else {
    console.log('\nNot Deploying fr, so using deployer address as owner everywhere:');

    console.log('\tProxyAdminLockOwner:', deployerAddress);
    console.log('\tAccessControlLockOwner:', deployerAddress);
    console.log('\tBeaconOwner:', deployerAddress);
    console.log('\tFactoriesProxyOwner:', LOCAL_RICH_WALLETS[1].address); // Cannot be deployer cause later it will fail to execute the lensFactory primitives deployments
    console.log('\tRulesOwner:', deployerAddress);
    console.log('\tActionsOwner:', deployerAddress);
    console.log('\tPrimitivesOwner:', deployerAddress);
  }
  console.log('\n-------------------------------------------------------------------\n\n');

  await deployLock('AppLock', proxyAdminLockOwner ?? deployerAddress);
  await deployLock('AccountLock', proxyAdminLockOwner ?? deployerAddress);
  await deployLock('FeedLock', proxyAdminLockOwner ?? deployerAddress);
  await deployLock('GraphLock', proxyAdminLockOwner ?? deployerAddress);
  await deployLock('GroupLock', proxyAdminLockOwner ?? deployerAddress);
  await deployLock('NamespaceLock', proxyAdminLockOwner ?? deployerAddress);
  await deployLock('AccessControlLock', accessControlLockOwner ?? deployerAddress);

  await deployImplementations(DEPLOYING_MIGRATION);
  await deployBeacons(beaconOwner ?? deployerAddress);
  await deployFactories(
    rulesOwner ?? deployerAddress,
    factoriesProxyOwner ?? LOCAL_RICH_WALLETS[1].address,
    DEPLOYING_MIGRATION
  );
  await deployLensPrimitives(primitivesOwner ?? deployerAddress, DEPLOYING_MIGRATION);
  if (!DEPLOYING_MIGRATION) {
    const actionHub = await deployLensActionHub(
      factoriesProxyOwner ?? deployerAddress,
      treasuryAddress ?? deployerAddress,
      treasuryFeeBps ?? 0
    );
    await deployLensAccessControl(primitivesOwner ?? deployerAddress);
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
