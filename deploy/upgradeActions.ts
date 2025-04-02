import { deployActionImplsAndUpgrade } from './deployActions';
import { generateEnvFile, loadAddressBook } from './lensUtils';
import { getWallet } from './utils';

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

  const addressBook = loadAddressBook();
  const actionHubAddress = addressBook['ActionHub'].address;

  if (!actionHubAddress) {
    throw new Error('ActionHub address not found in the address book');
  } else {
    console.log(
      `ActionHub address being used for new action implementations: ${actionHubAddress}\n\n`
    );
  }

  await deployActionImplsAndUpgrade(actionHubAddress, getWallet(proxyAdminPk));
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
