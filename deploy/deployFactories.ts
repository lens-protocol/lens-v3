import {
  deployLensContract,
  deployLensContractAsProxy,
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
} from './lensUtils';

export default async function deployFactories(rulesOwner: string, factoriesProxyOwner: string): Promise<void> {
  const metadataURI = 'https://lens.dev/metadata'; // TODO: Change this to the actual metadata URI

  const factories: ContractInfo[] = [
    // Factories
    { contractName: 'AccessControlFactory', contractType: ContractType.Factory },
    {
      contractName: 'AccountFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AccountBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      contractName: 'AppFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('AppBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      contractName: 'FeedFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('FeedBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      contractName: 'GraphFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GraphBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      contractName: 'GroupFactory',
      contractType: ContractType.Factory,
      constructorArguments: [
        loadContractAddressFromAddressBook('GroupBeacon'),
        loadContractAddressFromAddressBook('Lock'),
      ],
    },
    {
      contractName: 'NamespaceFactory',
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
    deployedContracts[factory.contractName] = await deployLensContractAsProxy(factory, factoriesProxyOwner);
  }

  for (const rule of rules) {
    deployedContracts[rule.contractName] = await deployLensContract(rule);
  }

  // lens factory
  const lensFactory_artifactName = 'LensFactory';
  const lensFactory_args = [
    deployedContracts['AccessControlFactory'].address,
    deployedContracts['AccountFactory'].address,
    deployedContracts['AppFactory'].address,
    deployedContracts['GroupFactory'].address,
    deployedContracts['FeedFactory'].address,
    deployedContracts['GraphFactory'].address,
    deployedContracts['NamespaceFactory'].address,
    deployedContracts['AccountBlockingRule'].address,
    deployedContracts['GroupGatedFeedRule'].address,
    deployedContracts['UsernameSimpleCharsetNamespaceRule'].address,
  ];

  await deployLensContract({
    contractName: lensFactory_artifactName,
    contractType: ContractType.Factory,
    constructorArguments: lensFactory_args,
  });
}
