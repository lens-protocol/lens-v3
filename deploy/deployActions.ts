import {
  deployLensContract,
  ContractType,
  ContractInfo,
} from './lensUtils';

export async function deployActions(actionHub: string): Promise<void> {
  const metadataURI = 'https://lens.dev/metadata'; // TODO: Change this to the actual metadata URI
  const contracts: ContractInfo[] = [
    // Actions
    { contractName: 'TippingAccountAction', contractType: ContractType.Action, constructorArguments: [actionHub, metadataURI] },
    { contractName: 'SimpleCollectAction', contractType: ContractType.Action, constructorArguments: [actionHub, metadataURI] },
  ];

  for (const contract of contracts) {
    await deployLensContract(contract);
  }
}
