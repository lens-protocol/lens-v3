import deployImplementations from './deployImplementations';
import deployFactories from './deployFactories';
import { deployLensPrimitives, deployLensAccessControl, deployLensActionHub } from './deployAux';
import { deployRules, deployRulesImplsAndUpgrade } from './deployRules';
import { deployActions } from './deployActions';
import { generateEnvFile } from './lensUtils';
import { deployBeacons, deployLock } from './deployProxyStuff';
import { getWallet, LOCAL_RICH_WALLETS } from './utils';

async function deploy() {
  const regularDeployerPk = process.env.WALLET_PRIVATE_KEY;
  if (!regularDeployerPk) {
    throw new Error('WALLET_PRIVATE_KEY not found in environment variables');
  }
  const regularDeployerPkBalance = await getWallet(regularDeployerPk).getBalance();
  console.log('Regular deployer balance:', regularDeployerPkBalance.toString());

  const proxyAdminPk = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!proxyAdminPk) {
    throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
  }
  const proxyAdminPkBalance = await getWallet(proxyAdminPk).getBalance();
  console.log('Proxy admin balance:', proxyAdminPkBalance.toString());

  await deployRulesImplsAndUpgrade(getWallet(proxyAdminPk));
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
