import {
  deployLensContract,
  ContractType,
  ContractInfo,
} from './lensUtils';

export async function deployRules(): Promise<void> {
  const contracts: ContractInfo[] = [
    // Feed Rules
    { contractName: 'GroupGatedFeedRule', contractType: ContractType.Rule },
    { contractName: 'RestrictedSignersFeedRule', contractType: ContractType.Rule },
    { contractName: 'SimplePaymentFeedRule', contractType: ContractType.Rule },
    { contractName: 'TokenGatedFeedRule', contractType: ContractType.Rule },
    // Post Rules
    { contractName: 'FollowersOnlyPostRule', contractType: ContractType.Rule },
    // Graph Rules
    { contractName: 'RestrictedSignersGraphRule', contractType: ContractType.Rule },
    { contractName: 'TokenGatedGraphRule', contractType: ContractType.Rule },
    // Follow Rules
    { contractName: 'SimplePaymentFollowRule', contractType: ContractType.Rule },
    { contractName: 'TokenGatedFollowRule', contractType: ContractType.Rule },
    // Group Rules
    { contractName: 'MembershipApprovalGroupRule', contractType: ContractType.Rule },
    { contractName: 'SimplePaymentGroupRule', contractType: ContractType.Rule },
    { contractName: 'TokenGatedGroupRule', contractType: ContractType.Rule },
    // Username Rules
    { contractName: 'CharsetUsernameRule', contractType: ContractType.Rule },
    { contractName: 'LengthUsernameRule', contractType: ContractType.Rule },
    { contractName: 'SimplePaymentUsernameRule', contractType: ContractType.Rule },
    { contractName: 'TokenGatedUsernameRule', contractType: ContractType.Rule },
  ];

  for (const contract of contracts) {
    await deployLensContract(contract);
  }
}
