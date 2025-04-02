import {
  ContractType,
  ContractInfo,
  deployLensContractWithCreate2,
  getInitializeEncodedCall,
  loadAddressBook,
  saveAddressBook,
} from './lensUtils';
import { getWallet } from './utils';
import { ethers } from 'ethers';
import hre from 'hardhat';
async function deploy() {
  const proxyAdminPrivateKey = process.env.PROXY_ADMIN_PRIVATE_KEY;
  if (!proxyAdminPrivateKey) {
    throw new Error('PROXY_ADMIN_PRIVATE_KEY not found in environment variables');
  }
  const proxyAdminAddress = await getWallet(proxyAdminPrivateKey).getAddress();

  const ownerPrivateKey = process.env.OWNER_PRIVATE_KEY;
  if (!ownerPrivateKey) {
    throw new Error('OWNER_PRIVATE_KEY not found in environment variables');
  }
  const ownerAddress = await getWallet(ownerPrivateKey).getAddress();

  /////////////////// SETUP ACTION HUB ///////////////////

  const actionHubInfo = await deployLensContractWithCreate2({
    contractName: 'ActionHub',
    contractType: ContractType.Aux,
    constructorArguments: [],
  }, proxyAdminAddress);
  const actionHubAddress = actionHubInfo.address;

  const lensFeesInfo = await deployLensContractWithCreate2(
    {
      contractName: 'LensFees',
      contractType: ContractType.Aux,
    constructorArguments: [process.env.TREASURY_ADDRESS, process.env.TREASURY_FEE_BPS],
  }, proxyAdminAddress);

  /////////////////// SETUP LENS FEES AND ACTIONS ///////////////////

  const actionsToDeploy: ContractInfo[] = [
    {
      contractName: 'TippingAccountAction',
      contractType: ContractType.Action,
      constructorArguments: [actionHubAddress],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'TippingPostAction',
      contractType: ContractType.Action,
      constructorArguments: [actionHubAddress],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'SimpleCollectAction',
      contractType: ContractType.Action,
      constructorArguments: [actionHubAddress],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
  ];

  /////////////////// SETUP 3 ///////////////////

  const rulesToDeploy: ContractInfo[] = [
    {
      contractName: 'AccountBlockingRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'AdditionRemovalPidGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'BanMemberGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'GroupGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'UsernameLengthNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'UsernameReservedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'UsernameSimpleCharsetNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'SimplePaymentFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'TokenGatedFeedRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'TokenGatedGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
  {
    contractName: 'FollowersOnlyPostRule',
    contractType: ContractType.Rule,
    constructorArguments: [],
    initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'GroupGatedGraphRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'SimplePaymentFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'TokenGatedFollowRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'MembershipApprovalGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'SimplePaymentGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'TokenGatedGroupRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'TokenGatedNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    },
    {
      contractName: 'UsernamePricePerLengthNamespaceRule',
      contractType: ContractType.Rule,
      constructorArguments: [],
      initializerCalldata: getInitializeEncodedCall(ownerAddress, ''),
    }
  ];

  /////////////////////////////////////////////

  /////////////////// DEPLOY ACTIONS ///////////////////

  const deployedActions: ContractInfo[] = [];

  for (const actionToDeploy of actionsToDeploy) {
    const deployedAction = await deployLensContractWithCreate2(actionToDeploy, proxyAdminAddress, actionToDeploy.initializerCalldata);
    deployedActions.push(deployedAction);
  }

  // /////////////////// DEPLOY RULES ///////////////////

  const deployedRules: ContractInfo[] = [];

  for (const ruleToDeploy of rulesToDeploy) {
    const deployedRule = await deployLensContractWithCreate2(ruleToDeploy, proxyAdminAddress, ruleToDeploy.initializerCalldata);
    deployedRules.push(deployedRule);
  }


  /////////////////// VERIFY OWNERS AND METADATA ///////////////////
  console.log(`\x1b[33m\n-------------------------------------------------------\nVerifying owners and metadata for deployed contracts...\x1b[0m`);

  const artifact = await hre.artifacts.readArtifact('SimpleCollectAction');

  const addressBook = loadAddressBook();

  for (const deployedAction of deployedActions) {
    const actionAddress = deployedAction.address!;
    const action =  new ethers.Contract(
      actionAddress,
      artifact.abi,
      getWallet()
    );
    const owner = await action.owner();
    const metadataURI = await action.getMetadataURI();
    console.log(`Action ${deployedAction.contractName} is owned by ${owner} and has metadata URI '${metadataURI}'`);
    addressBook[deployedAction.contractName].owner = owner;
    addressBook[deployedAction.contractName].metadataURI = metadataURI;
  }

  for (const deployedRule of deployedRules) {
    const ruleAddress = deployedRule.address!;
    const rule =  new ethers.Contract(
      ruleAddress,
      artifact.abi,
      getWallet()
    );
    const owner = await rule.owner();
    const metadataURI = await rule.getMetadataURI();
    console.log(`Rule ${deployedRule.contractName} is owned by ${owner} and has metadata URI '${metadataURI}'`);
    addressBook[deployedRule.contractName].owner = owner;
    addressBook[deployedRule.contractName].metadataURI = metadataURI;
  }

  saveAddressBook(addressBook);
}

if (require.main === module) {
  deploy()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export default deploy;
