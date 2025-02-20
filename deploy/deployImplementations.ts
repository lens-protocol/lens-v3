import { deployLensContract, ContractType, ContractInfo } from './lensUtils';

export default async function deployImplementations(DEPLOYING_MIGRATION: boolean): Promise<void> {
  const contracts: ContractInfo[] = [
    { name: 'AppImpl', contractName: DEPLOYING_MIGRATION ? 'MigrationApp' : 'App', contractType: ContractType.Implementation },
    { name: 'AccountImpl', contractName: DEPLOYING_MIGRATION ? 'MigrationAccount' : 'Account', contractType: ContractType.Implementation },
    { name: 'FeedImpl', contractName: DEPLOYING_MIGRATION ? 'MigrationFeed' : 'Feed', contractType: ContractType.Implementation },
    { name: 'GraphImpl', contractName: DEPLOYING_MIGRATION ? 'MigrationGraph' : 'Graph', contractType: ContractType.Implementation },
    { name: 'GroupImpl', contractName: 'Group', contractType: ContractType.Implementation },
    { name: 'NamespaceImpl', contractName: DEPLOYING_MIGRATION ? 'MigrationNamespace' : 'Namespace', contractType: ContractType.Implementation },
  ];

  for (const contract of contracts) {
    await deployLensContract(contract);
  }
}
