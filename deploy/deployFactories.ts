import {
  deployLensContract,
  deployLensContractAsProxy,
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
} from './lensUtils';
import { ZeroAddress } from 'ethers';



export default async function deployFactories(rulesOwner: string, factoriesProxyOwner: string, DEPLOYING_MIGRATION: boolean): Promise<void> {
  const metadataURI = 'https://lens.dev/metadata'; // TODO: Change this to the actual metadata URI

  const factories: ContractInfo[] = [
    // Factories
    { name: 'AccessControlFactory', contractName: DEPLOYING_MIGRATION ? 'MigrationAccessControlFactory' : 'AccessControlFactory', contractType: ContractType.Factory },
    {
      name: 'AccountFactory',
      contractName: 'AccountFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AccountBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      name: 'AppFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationAppFactory' : 'AppFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AppBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      name: 'FeedFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationFeedFactory' : 'FeedFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('FeedBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      name: 'GraphFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationGraphFactory' : 'GraphFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GraphBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      name: 'GroupFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationGroupFactory' : 'GroupFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GroupBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      name: 'NamespaceFactory',
      contractName: DEPLOYING_MIGRATION ? 'MigrationNamespaceFactory' : 'NamespaceFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('NamespaceBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    }]

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
  ];

  const deployedContracts: Record<string, ContractInfo> = {};

  for (const factory of factories) {
    deployedContracts[factory.name ?? factory.contractName] = await deployLensContractAsProxy(factory, factoriesProxyOwner);
  }

  if (!DEPLOYING_MIGRATION) {
    for (const rule of rules) {
      deployedContracts[rule.contractName] = await deployLensContract(rule);
    }
  }

  // lens factory
  const lensFactory_artifactName = DEPLOYING_MIGRATION ? 'MigrationLensFactory' : 'LensFactory';
  const lensFactory_args = [
    deployedContracts['AccessControlFactory'].address,
    deployedContracts['AccountFactory'].address,
    deployedContracts['AppFactory'].address,
    deployedContracts['GroupFactory'].address,
    deployedContracts['FeedFactory'].address,
    deployedContracts['GraphFactory'].address,
    deployedContracts['NamespaceFactory'].address,
    DEPLOYING_MIGRATION ? ZeroAddress : deployedContracts['AccountBlockingRule'].address,
    DEPLOYING_MIGRATION ? ZeroAddress : deployedContracts['GroupGatedFeedRule'].address,
    DEPLOYING_MIGRATION ? ZeroAddress : deployedContracts['UsernameSimpleCharsetNamespaceRule'].address,
  ];

  await deployLensContractAsProxy(
    {
      name: 'LensFactory',
      contractName: lensFactory_artifactName,
      contractType: ContractType.Factory,
      constructorArguments: lensFactory_args,
    },
    factoriesProxyOwner
  );
}
