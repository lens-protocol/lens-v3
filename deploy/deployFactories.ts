import {
  deployLensContract,
  ContractType,
  ContractInfo,
  loadContractAddressFromAddressBook,
} from './lensUtils';

export default async function deployFactories(): Promise<void> {
  const metadataURI = 'https://lens.dev/metadata'; // TODO: Change this to the actual metadata URI

  const contracts: ContractInfo[] = [
    // Factories
    { contractName: 'AccessControlFactory', contractType: ContractType.Factory },
    { contractName: 'AccountFactory', contractType: ContractType.Factory },
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
    },
    {
      contractName: 'AccountBlockingRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'GroupGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
  ];
  const deployedContracts: Record<string, ContractInfo> = {};
  for (const contract of contracts) {
    deployedContracts[contract.contractName] = await deployLensContract(contract);
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
  ];

  await deployLensContract({
    contractName: lensFactory_artifactName,
    contractType: ContractType.Factory,
    constructorArguments: lensFactory_args,
  });
}
