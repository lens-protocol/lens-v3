import {
  deployLensContract,
  ContractType,
  ContractInfo,
} from './lensUtils';

export async function deployActions(actionHub: string): Promise<void> {
  const contracts: ContractInfo[] = [
    // Actions
    { contractName: 'TippingAccountAction', contractType: ContractType.Action, constructorArguments: [actionHub] },
    { contractName: 'SimpleCollectAction', contractType: ContractType.Action, constructorArguments: [actionHub] },
  ];

  for (const contract of contracts) {
    await deployLensContract(contract);
  }
}
