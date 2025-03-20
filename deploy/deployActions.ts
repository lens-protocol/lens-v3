import { ethers } from 'ethers';
import { deployLensContractAsProxy, ContractType, ContractInfo } from './lensUtils';

export async function deployActions(actionHub: string, actionsOwner: string): Promise<void> {
  const metadataURI = '';
  const contracts: ContractInfo[] = [
    // Actions
    {
      contractName: 'TippingAccountAction',
      contractType: ContractType.Action,
      constructorArguments: [actionHub],
    },
    {
      contractName: 'TippingPostAction',
      contractType: ContractType.Action,
      constructorArguments: [actionHub],
    },
    {
      contractName: 'SimpleCollectAction',
      contractType: ContractType.Action,
      constructorArguments: [actionHub],
    },
  ];

  const initializerABI = ['function initialize(address owner, string memory metadataURI) external'];
  const initializerInterface = new ethers.Interface(initializerABI);
  const initializeEncodedCall = initializerInterface.encodeFunctionData('initialize', [
    actionsOwner,
    metadataURI,
  ]);

  for (const contract of contracts) {
    await deployLensContractAsProxy(contract, actionsOwner, initializeEncodedCall);
  }
}
