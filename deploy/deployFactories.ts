import {
  deployLensContractAsProxy,
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
} from './lensUtils';
import { assert, Contract, ZeroAddress } from 'ethers';
import { utils } from 'zksync-ethers';
import { getWallet } from './utils';

export default async function deployFactories(
  rulesOwner: string,
  factoriesProxyOwner: string,
  DEPLOYING_MIGRATION: boolean
): Promise<void> {
  const metadataURI = '';

  const deployer = getWallet();
  console.log(`Deployer address: ${deployer.address}`);

  const nonce = await deployer.getNonce();

  // TODO: This is a super-dirty hack which doesn't work half of the time (or if you change anything in deployment script).
  // Probably the problem has something to do with libraries already deployed or something.
  // If it fails - restart the node or play with nonce + values.
  const contractDeployer = new Contract(
    utils.CONTRACT_DEPLOYER_ADDRESS,
    utils.CONTRACT_DEPLOYER.fragments,
    deployer
  );

  // Print all addresses from nonce 0 to nonce + 20
  for (let i = 0; i < 30; i++) {
    const address = await contractDeployer.getNewAddressCreate.staticCall(
      deployer.address,
      nonce + i
    );
    console.log(`Nonce ${i} address: ${address}`);
  }
  let predictedLensFactoryAddress = await contractDeployer.getNewAddressCreate.staticCall(
    deployer.address,
    DEPLOYING_MIGRATION ? nonce + 15 : nonce + 18
  );

  const factories: ContractInfo[] = [
    // Factories
    {
      name: 'AccessControlFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationAccessControlFactory' : 'AccessControlFactory',
      contractType: ContractType.Factory,
      constructorArguments: [loadContractAddressFromAddressBook('AccessControlLock')],
    },
    {
      name: 'AccountFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationAccountFactory' : 'AccountFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AccountBeacon'),
        loadContractAddressFromAddressBook('AccountLock'),
      ],
    },
    {
      name: 'AppFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationAppFactory' : 'AppFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AppBeacon'),
        loadContractAddressFromAddressBook('AppLock'),
      ],
    },
    {
      name: 'FeedFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationFeedFactory' : 'FeedFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('FeedBeacon'),
        loadContractAddressFromAddressBook('FeedLock'),
        predictedLensFactoryAddress,
      ],
    },
    {
      name: 'GraphFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationGraphFactory' : 'GraphFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GraphBeacon'),
        loadContractAddressFromAddressBook('GraphLock'),
        predictedLensFactoryAddress,
      ],
    },
    {
      name: 'GroupFactory',
      contractName: 'GroupFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GroupBeacon'),
        loadContractAddressFromAddressBook('GroupLock'),
        predictedLensFactoryAddress,
      ],
    },
    {
      name: 'NamespaceFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationNamespaceFactory' : 'NamespaceFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('NamespaceBeacon'),
        loadContractAddressFromAddressBook('NamespaceLock'),
        predictedLensFactoryAddress,
      ],
    },
  ];

  const rules: ContractInfo[] = [
    // Prerequisite rules for LensFactory
    {
      contractName: 'AccountBlockingRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'GroupGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'UsernameSimpleCharsetNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'BanMemberGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'AdditionRemovalPidGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
  ];

  const deployedContracts: Record<string, ContractInfo> = {};

  for (const factory of factories) {
    deployedContracts[factory.name ?? factory.contractName] = await deployLensContractAsProxy(
      factory,
      factoriesProxyOwner
    );
  }

  if (!DEPLOYING_MIGRATION) {
    for (const rule of rules) {
      deployedContracts[rule.contractName] = await deployLensContractAsProxy(rule, rulesOwner);
    }
  }

  // lens factory
  const lensFactory_artifactName = DEPLOYING_MIGRATION ? 'MigrationLensFactory' : 'LensFactory';
  const lensFactory_args = [
    {
      accessControlFactory: deployedContracts['AccessControlFactory'].address,
      accountFactory: deployedContracts['AccountFactory'].address,
      appFactory: deployedContracts['AppFactory'].address,
      groupFactory: deployedContracts['GroupFactory'].address,
      feedFactory: deployedContracts['FeedFactory'].address,
      graphFactory: deployedContracts['GraphFactory'].address,
      namespaceFactory: deployedContracts['NamespaceFactory'].address,
    },
    {
      accountBlockingRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['AccountBlockingRule'].address,
      groupGatedFeedRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['GroupGatedFeedRule'].address,
      usernameSimpleCharsetRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['UsernameSimpleCharsetNamespaceRule'].address,
      banMemberGroupRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['BanMemberGroupRule'].address,
      addRemovePidGroupRule: DEPLOYING_MIGRATION
        ? ZeroAddress
        : deployedContracts['AdditionRemovalPidGroupRule'].address,
    },
  ];

  const wasLensFactoryDeployed = loadContractAddressFromAddressBook('LensFactory') !== undefined;

  const lensFactoryInfo = await deployLensContractAsProxy(
    {
      name: 'LensFactory',
      contractName: lensFactory_artifactName,
      contractType: ContractType.Factory,
      constructorArguments: lensFactory_args,
    },
    factoriesProxyOwner
  );

  if (wasLensFactoryDeployed == false) {
    console.log(
      `LensFactory address: ${lensFactoryInfo.address} <<< ??? >>> ${predictedLensFactoryAddress} Predicted LensFactory address`
    );
    assert(
      lensFactoryInfo.address === predictedLensFactoryAddress,
      'Predicted LensFactory address doesnt match the actual deployed address',
      'VALUE_MISMATCH'
    );
  }
}
