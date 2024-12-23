import { deploy, camelToAllCaps } from './utils';
import { writeFileSync } from 'fs';

enum ContractType {
  PostAction,
  AccountAction,
  FeedRule,
  PostRule,
  GraphRule,
  FollowRule,
  GroupRule,
  UsernameRule,
}

interface DeployContract {
  contractName: string;
  contractType: ContractType;
  address?: string;
}

export async function deployRules() {
  const contracts: DeployContract[] = [
    // Actions
    { contractName: 'TippingAccountAction', contractType: ContractType.AccountAction },
    { contractName: 'SimpleCollectAction', contractType: ContractType.PostAction },
    // Feed Rules
    { contractName: 'GroupGatedFeedRule', contractType: ContractType.FeedRule },
    { contractName: 'RestrictedSignersFeedRule', contractType: ContractType.FeedRule },
    { contractName: 'SimplePaymentFeedRule', contractType: ContractType.FeedRule },
    { contractName: 'TokenGatedFeedRule', contractType: ContractType.FeedRule },
    // Post Rules
    { contractName: 'FollowersOnlyPostRule', contractType: ContractType.PostRule },
    // Graph Rules
    { contractName: 'RestrictedSignersGraphRule', contractType: ContractType.GraphRule },
    { contractName: 'TokenGatedGraphRule', contractType: ContractType.GraphRule },
    // Follow Rules
    { contractName: 'SimplePaymentFollowRule', contractType: ContractType.FollowRule },
    { contractName: 'TokenGatedFollowRule', contractType: ContractType.FollowRule },
    // Group Rules
    { contractName: 'MembershipApprovalGroupRule', contractType: ContractType.GroupRule },
    { contractName: 'SimplePaymentGroupRule', contractType: ContractType.GroupRule },
    { contractName: 'TokenGatedGroupRule', contractType: ContractType.GroupRule },
    // Username Rules
    { contractName: 'CharsetUsernameRule', contractType: ContractType.UsernameRule },
    { contractName: 'LengthUsernameRule', contractType: ContractType.UsernameRule },
    { contractName: 'SimplePaymentUsernameRule', contractType: ContractType.UsernameRule },
    { contractName: 'TokenGatedUsernameRule', contractType: ContractType.UsernameRule },
  ];

  for (const contract of contracts) {
    const address = await deploy(contract.contractName, []);
    contract.address = address;
  }

  const outputLines: string[] = [];

  outputLines.push('# ACTIONS');
  contracts
    .filter((contract) => contract.contractType === ContractType.AccountAction)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  contracts
    .filter((contract) => contract.contractType === ContractType.PostAction)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  outputLines.push('\n# RULES');

  outputLines.push('# Feed Rules');
  contracts
    .filter((contract) => contract.contractType === ContractType.FeedRule)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  outputLines.push('# Feed -> Post Rules');
  contracts
    .filter((contract) => contract.contractType === ContractType.PostRule)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  outputLines.push('# Graph Rules');
  contracts
    .filter((contract) => contract.contractType === ContractType.GraphRule)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  outputLines.push('# Graph -> Follow Rules');
  contracts
    .filter((contract) => contract.contractType === ContractType.FollowRule)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  outputLines.push('# Group Rules');
  contracts
    .filter((contract) => contract.contractType === ContractType.GroupRule)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  outputLines.push('# Username Rules');
  contracts
    .filter((contract) => contract.contractType === ContractType.UsernameRule)
    .forEach((contract) => {
      outputLines.push(`${camelToAllCaps(contract.contractName)}="${contract.address}"`);
    });

  const output = outputLines.join('\n');
  writeFileSync('deployed_rules.txt', output);

  console.log(`\n\nDeployed Contracts:\n`);
  console.log(output);

  console.log('\n\nContracts deployed and addresses saved to deployed_contracts.txt');
}
