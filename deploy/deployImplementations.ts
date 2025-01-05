import { deployLensContract, ContractType, ContractInfo } from './lensUtils';

export default async function deployImplementations(): Promise<void> {
  const contracts: ContractInfo[] = [
    { name: 'AppImpl', contractName: 'App', contractType: ContractType.Implementation },
    { name: 'AccountImpl', contractName: 'Account', contractType: ContractType.Implementation },
    { name: 'FeedImpl', contractName: 'Feed', contractType: ContractType.Implementation },
    { name: 'GraphImpl', contractName: 'Graph', contractType: ContractType.Implementation },
    { name: 'GroupImpl', contractName: 'Group', contractType: ContractType.Implementation },
    { name: 'NamespaceImpl', contractName: 'Namespace', contractType: ContractType.Implementation },
  ];

  for (const contract of contracts) {
    await deployLensContract(contract);
  }
}
