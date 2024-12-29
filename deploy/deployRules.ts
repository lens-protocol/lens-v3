import { deployLensContract, ContractType, ContractInfo } from './lensUtils';

export async function deployRules(): Promise<void> {
  const metadataURI = 'https://lens.dev/metadata'; // TODO: Change this to the actual metadata URI
  const contracts: ContractInfo[] = [
    // Feed Rules
    {
      contractName: 'RestrictedSignersFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'SimplePaymentFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'TokenGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    // Post Rules
    {
      contractName: 'FollowersOnlyPostRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    // Graph Rules
    {
      contractName: 'RestrictedSignersGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'TokenGatedGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    // Follow Rules
    {
      contractName: 'SimplePaymentFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'TokenGatedFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    // Group Rules
    {
      contractName: 'MembershipApprovalGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'SimplePaymentGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'TokenGatedGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    // Namespace Rules
    {
      contractName: 'UsernameCharsetNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'UsernameLengthNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'UsernameReservedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'SimplePaymentNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
    {
      contractName: 'TokenGatedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [metadataURI],
    },
  ];

  for (const contract of contracts) {
    await deployLensContract(contract);
  }
}
