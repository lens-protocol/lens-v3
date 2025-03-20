import { ethers } from 'ethers';
import { ContractType, ContractInfo, deployLensContractAsProxy } from './lensUtils';

export async function deployRules(rulesOwner: string): Promise<void> {
  const metadataURI = '';
  const contracts: ContractInfo[] = [
    // Feed Rules
    {
      contractName: 'SimplePaymentFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'TokenGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    // Post Rules
    {
      contractName: 'FollowersOnlyPostRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    // Graph Rules
    {
      contractName: 'GroupGatedGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'TokenGatedGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    // Follow Rules
    {
      contractName: 'SimplePaymentFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'TokenGatedFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    // Group Rules
    {
      contractName: 'MembershipApprovalGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'SimplePaymentGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'TokenGatedGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    // {
    //   contractName: 'BanMemberGroupRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [],
    // },
    // Namespace Rules
    // {
    //   contractName: 'UsernameCharsetNamespaceRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [],
    // },
    {
      contractName: 'UsernameLengthNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'UsernameReservedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    // {
    //   contractName: 'SimplePaymentNamespaceRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [],
    // },
    {
      contractName: 'TokenGatedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
    {
      contractName: 'UsernamePricePerLengthNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
    },
  ];

  const initializerABI = ['function initialize(address owner, string memory metadataURI) external'];
  const initializerInterface = new ethers.Interface(initializerABI);
  const initializeEncodedCall = initializerInterface.encodeFunctionData('initialize', [
    rulesOwner,
    metadataURI,
  ]);

  for (const contract of contracts) {
    await deployLensContractAsProxy(contract, rulesOwner, initializeEncodedCall);
  }
}
