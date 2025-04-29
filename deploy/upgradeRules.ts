import {
  deployImplAndUpgradeTransparentProxy,
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
  getTransparentUpgradeableProxyImplementationAddress,
  getContractBytecodeHashByAddress,
  getArtifactBytecodeHash
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

  const accessControlLock = loadContractAddressFromAddressBook('AccessControlLock');
  if (!accessControlLock) {
    throw new Error('AccessControlLock not found in address book');
  }
  const accountLock = loadContractAddressFromAddressBook('AccountLock');
  if (!accountLock) {
    throw new Error('AccountLock not found in address book');
  }
  const accountBeacon = loadContractAddressFromAddressBook('AccountBeacon');
  if (!accountBeacon) {
    throw new Error('AccountBeacon not found in address book');
  }
  const appLock = loadContractAddressFromAddressBook('AppLock');
  if (!appLock) {
    throw new Error('AppLock not found in address book');
  }
  const appBeacon = loadContractAddressFromAddressBook('AppBeacon');
  if (!appBeacon) {
    throw new Error('AppBeacon not found in address book');
  }
  const feedLock = loadContractAddressFromAddressBook('FeedLock');
  if (!feedLock) {
    throw new Error('FeedLock not found in address book');
  }
  const feedBeacon = loadContractAddressFromAddressBook('FeedBeacon');
  if (!feedBeacon) {
    throw new Error('FeedBeacon not found in address book');
  }
  const graphLock = loadContractAddressFromAddressBook('GraphLock');
  if (!graphLock) {
    throw new Error('GraphLock not found in address book');
  }
  const graphBeacon = loadContractAddressFromAddressBook('GraphBeacon');
  if (!graphBeacon) {
    throw new Error('GraphBeacon not found in address book');
  }
  const groupLock = loadContractAddressFromAddressBook('GroupLock');
  if (!groupLock) {
    throw new Error('GroupLock not found in address book');
  }
  const groupBeacon = loadContractAddressFromAddressBook('GroupBeacon');
  if (!groupBeacon) {
    throw new Error('GroupBeacon not found in address book');
  }
  const namespaceLock = loadContractAddressFromAddressBook('NamespaceLock');
  if (!namespaceLock) {
    throw new Error('NamespaceLock not found in address book');
  }
  const namespaceBeacon = loadContractAddressFromAddressBook('NamespaceBeacon');
  if (!namespaceBeacon) {
    throw new Error('NamespaceBeacon not found in address book');
  }

  const accessControlFactory = loadContractAddressFromAddressBook('AccessControlFactory');
  if (!accessControlFactory) {
    throw new Error('AccessControlFactory not found in address book');
  }
  const accountFactory = loadContractAddressFromAddressBook('AccountFactory');
  if (!accountFactory) {
    throw new Error('AccountFactory not found in address book');
  }
  const appFactory = loadContractAddressFromAddressBook('AppFactory');
  if (!appFactory) {
    throw new Error('AppFactory not found in address book');
  }
  const groupFactory = loadContractAddressFromAddressBook('GroupFactory');
  if (!groupFactory) {
    throw new Error('GroupFactory not found in address book');
  }
  const feedFactory = loadContractAddressFromAddressBook('FeedFactory');
  if (!feedFactory) {
    throw new Error('FeedFactory not found in address book');
  }
  const graphFactory = loadContractAddressFromAddressBook('GraphFactory');
  if (!graphFactory) {
    throw new Error('GraphFactory not found in address book');
  }
  const namespaceFactory = loadContractAddressFromAddressBook('NamespaceFactory');
  if (!namespaceFactory) {
    throw new Error('NamespaceFactory not found in address book');
  }
  const lensFactory = loadContractAddressFromAddressBook('LensFactory');
  if (!lensFactory) {
    throw new Error('LensFactory not found in address book');
  }

  const accountBlockingRule = loadContractAddressFromAddressBook('AccountBlockingRule');
  if (!accountBlockingRule) {
    throw new Error('AccountBlockingRule not found in address book');
  }
  const groupGatedFeedRule = loadContractAddressFromAddressBook('GroupGatedFeedRule');
  if (!groupGatedFeedRule) {
    throw new Error('GroupGatedFeedRule not found in address book');
  }
  const usernameSimpleCharsetNamespaceRule = loadContractAddressFromAddressBook('UsernameSimpleCharsetNamespaceRule');
  if (!usernameSimpleCharsetNamespaceRule) {
    throw new Error('UsernameSimpleCharsetNamespaceRule not found in address book');
  }
  const banMemberGroupRule = loadContractAddressFromAddressBook('BanMemberGroupRule');
  if (!banMemberGroupRule) {
    throw new Error('BanMemberGroupRule not found in address book');
  }
  const additionRemovalPidGroupRule = loadContractAddressFromAddressBook('AdditionRemovalPidGroupRule');
  if (!additionRemovalPidGroupRule) {
    throw new Error('AdditionRemovalPidGroupRule not found in address book');
  }
  const usernameReservedNamespaceRule = loadContractAddressFromAddressBook('UsernameReservedNamespaceRule');
  if (!usernameReservedNamespaceRule) {
    throw new Error('UsernameReservedNamespaceRule not found in address book');
  }


  const factoriesToUpgrade: ContractInfo[] = [
      {
          contractName: 'AccessControlFactory',
          contractType: ContractType.Factory,
          constructorArguments: [accessControlLock]
      },
      {
          contractName: 'AccountFactory',
          contractType: ContractType.Factory,
          constructorArguments: [accountBeacon, accountLock]
      },
      {
          contractName: 'AppFactory',
          contractType: ContractType.Factory,
          constructorArguments: [appBeacon, appLock]
      },
      {
          contractName: 'FeedFactory',
          contractType: ContractType.Factory,
          constructorArguments: [feedBeacon, feedLock, lensFactory]
      },
      {
          contractName: 'GraphFactory',
          contractType: ContractType.Factory,
          constructorArguments: [graphBeacon, graphLock, lensFactory]
      },
      {
          contractName: 'GroupFactory',
          contractType: ContractType.Factory,
          constructorArguments: [groupBeacon, groupLock, lensFactory]
      },
      {
          contractName: 'NamespaceFactory',
          contractType: ContractType.Factory,
          constructorArguments: [namespaceBeacon, namespaceLock, lensFactory]
      },
      {
          contractName: 'LensFactory',
          contractType: ContractType.Factory,
          constructorArguments: [{
              accessControlFactory,
              accountFactory,
              appFactory,
              groupFactory,
              feedFactory,
              graphFactory,
              namespaceFactory
          },{
              accountBlockingRule,
              groupGatedFeedRule,
              usernameSimpleCharsetRule: usernameSimpleCharsetNamespaceRule,
              banMemberGroupRule,
              addRemovePidGroupRule: additionRemovalPidGroupRule,
              usernameReservedNamespaceRule
          }]
      }
  ]

  ///////////////////////////// TRANSPARENT UPGRADEABLE PROXY UPGRADES ///////////////////////////////////

  const upgradedFactories: ContractInfo[] = [];

  // for (const factory of factoriesToUpgrade) {
    const upgradedFactory = await deployImplAndUpgradeTransparentProxy(proxyOwnerWallet, {
      contractName: 'AccountBlockingRule',
      contractType: ContractType.Rule,
      constructorArguments: []
  });
    upgradedFactories.push(upgradedFactory);
  // }

  ///////////////////////////// VERIFICATION ///////////////////////////////////

  console.log('\n\n');
  console.log('//////////////////////////// VERIFICATION ///////////////////////////////////');

  // if (upgradedFactories.length !== factoriesToUpgrade.length) {
  //   throw new Error('Failed to upgrade all factories');
  // }

  for (const upgradedFactory of upgradedFactories) {
    const proxyImplementationOnchain = await getTransparentUpgradeableProxyImplementationAddress(upgradedFactory.address!);
    const bytecodeHash = await getContractBytecodeHashByAddress(proxyImplementationOnchain);
    const artifactBytecodeHash = await getArtifactBytecodeHash('AccountBlockingRule');
    if (bytecodeHash !== artifactBytecodeHash) {
      throw new Error(`${upgradedFactory.name} bytecode hash mismatch: ${bytecodeHash} !== ${artifactBytecodeHash}`);
    } else {
      console.log(`\x1b[32m${upgradedFactory.name} onchain bytecode hash verified: ${bytecodeHash} and matches artifact bytecode hash\x1b[0m`);
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
