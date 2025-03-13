import { deployLensContract, ContractType, ContractInfo } from './lensUtils';

export async function deployRules(rulesOwner: string): Promise<void> {
  const metadataURI = '';
  const contracts: ContractInfo[] = [
    // Feed Rules
    // {
    //   contractName: 'RestrictedSignersFeedRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [rulesOwner, metadataURI],
    // },
    {
      contractName: 'SimplePaymentFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'TokenGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    // Post Rules
    {
      contractName: 'FollowersOnlyPostRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    // Graph Rules
    {
      contractName: 'GroupGatedGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    // {
    //   contractName: 'RestrictedSignersGraphRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [rulesOwner, metadataURI],
    // },
    {
      contractName: 'TokenGatedGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    // Follow Rules
    {
      contractName: 'SimplePaymentFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'TokenGatedFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    // Group Rules
    {
      contractName: 'MembershipApprovalGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'SimplePaymentGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'TokenGatedGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    // {
    //   contractName: 'BanMemberGroupRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [rulesOwner, metadataURI],
    // },
    // Namespace Rules
    // {
    //   contractName: 'UsernameCharsetNamespaceRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [metadataURI],
    // },
    {
      contractName: 'UsernameLengthNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'UsernameReservedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    // {
    //   contractName: 'SimplePaymentNamespaceRule',
    //   contractType: ContractType.Rule,
    //   constructorArguments: [metadataURI],
    // },
    {
      contractName: 'TokenGatedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
    {
      contractName: 'UsernamePricePerLengthNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [rulesOwner, metadataURI],
    },
  ];

  for (const contract of contracts) {
    await deployLensContract(contract);
  }
}
