import * as hre from 'hardhat';
import { getWallet } from './utils';
import { ethers } from 'ethers';

// Address of the contract to interact with
const CONTRACT_ADDRESS = '0xB401e2DE30a833FB0A94B89CdE8Ff8F226a338aB';
if (!CONTRACT_ADDRESS) throw '⛔️ Provide address of the contract to interact with!';

// An example of a script to interact with the contract
export default async function () {
  console.log(`Running script to interact with contract ${CONTRACT_ADDRESS}`);

  // Load compiled contract info
  const contractArtifact = await hre.artifacts.readArtifact('Feed');

  // Initialize contract instance for interaction
  const contract = new ethers.Contract(
    CONTRACT_ADDRESS,
    contractArtifact.abi,
    getWallet() // Interact with the contract on behalf of this wallet
  );

  //   struct CreatePostParams {
  //     address author; // Multiple authors can be added in extraData
  //     address source; // Client source, if any
  //     string contentURI;
  //     uint256 quotedPostId;
  //     uint256 parentPostId;
  //     RuleConfiguration[] rules;
  //     RuleExecutionData feedRulesData;
  //     RuleExecutionData changeRulesQuotePostRulesData;
  //     RuleExecutionData changeRulesParentPostRulesData;
  //     RuleExecutionData quotesPostRulesData;
  //     RuleExecutionData parentsPostRulesData;
  //     DataElement[] extraData;
  // }

  console.log('Running interaction from: ', getWallet().address);

  // Run contract write function
  const transaction = await contract.createPost({
    author: getWallet().address,
    source: '0x0000000000000000000000000000000000000000',
    contentURI: 'https://example.com',
    quotedPostId: 0,
    parentPostId: 0,
    rules: [],
    feedRulesData: {
      dataForRequiredRules: [],
      dataForAnyOfRules: [],
    },
    changeRulesQuotePostRulesData: {
      dataForRequiredRules: [],
      dataForAnyOfRules: [],
    },
    changeRulesParentPostRulesData: {
      dataForRequiredRules: [],
      dataForAnyOfRules: [],
    },
    quotesPostRulesData: {
      dataForRequiredRules: [],
      dataForAnyOfRules: [],
    },
    parentsPostRulesData: {
      dataForRequiredRules: [],
      dataForAnyOfRules: [],
    },
    extraData: [],
  });
  console.log(`Transaction hash of deploying new Username Primitive: ${transaction.hash}`);

  // Wait until transaction is processed
  await transaction.wait();
}
