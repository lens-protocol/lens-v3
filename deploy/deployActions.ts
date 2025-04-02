import { ContractRunner, ethers } from 'ethers';
import {
  deployLensContractAsProxy,
  ContractType,
  ContractInfo,
  deployImplAndUpgradeTransparentProxy,
} from './lensUtils';

function getContracts(actionHub: string): ContractInfo[] {
  return [
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
}

export async function deployActions(actionHub: string, actionsOwner: string): Promise<void> {
  const metadataURI = '';
  const contracts = getContracts(actionHub);

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

export async function deployActionImplsAndUpgrade(
  actionHub: string,
  proxyAdminWallet: ContractRunner
): Promise<void> {
  const contracts = getContracts(actionHub);

  for (const contract of contracts) {
    await deployImplAndUpgradeTransparentProxy(proxyAdminWallet, contract);
  }
}
