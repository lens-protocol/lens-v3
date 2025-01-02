import { Contract, Wallet } from 'zksync-ethers';
import { deployContract, getWallet, LOCAL_RICH_WALLETS } from '../../deploy/utils';
import { assert, ethers } from 'ethers';
import { artifacts } from 'hardhat';
import { expect } from 'chai';

describe('Account', function () {
  let ownerWallet: Wallet;
  let lensFactory: Contract;
  let accountBlockingRule: Contract;
  let groupGatedFeedRule: Contract;

  before(async function () {
    ownerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    console.log('Owner:', await ownerWallet.getAddress());

    accountBlockingRule = await deployContract('AccountBlockingRule', ['uri://any'], {
      wallet: ownerWallet,
      silent: true,
    });
    let accountBlockingRuleAddress = await accountBlockingRule.getAddress();
    console.log('AccountBlockingRule:', accountBlockingRuleAddress);

    groupGatedFeedRule = await deployContract('GroupGatedFeedRule', ['uri://any'], {
      wallet: ownerWallet,
      silent: true,
    });
    let groupGatedFeedRuleAddress = await groupGatedFeedRule.getAddress();
    console.log('GroupGatedFeedRule:', groupGatedFeedRuleAddress);

    let accessControlFactoryAddress = await (
      await deployContract('AccessControlFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('AccessControlFactory:', accessControlFactoryAddress);
    let accountFactoryAddress = await (
      await deployContract('AccountFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('AccountFactory:', accountFactoryAddress);
    let appFactoryAddress = await (
      await deployContract('AppFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('AppFactory:', appFactoryAddress);
    let groupFactoryAddress = await (
      await deployContract('GroupFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('GroupFactory:', groupFactoryAddress);
    let feedFactoryAddress = await (
      await deployContract('FeedFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('FeedFactory:', feedFactoryAddress);
    let graphFactoryAddress = await (
      await deployContract('GraphFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('GraphFactory:', graphFactoryAddress);
    let namespaceFactoryAddress = await (
      await deployContract('NamespaceFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('NamespaceFactory:', namespaceFactoryAddress);

    lensFactory = await deployContract(
      'LensFactory',
      [
        accessControlFactoryAddress,
        accountFactoryAddress,
        appFactoryAddress,
        groupFactoryAddress,
        feedFactoryAddress,
        graphFactoryAddress,
        namespaceFactoryAddress,
        accountBlockingRuleAddress,
        groupGatedFeedRuleAddress,
      ],
      { wallet: ownerWallet, silent: true }
    );
  });

  it('Should emit proper rule configured events', async function () {
    // Call deployGraph on LensFactory
    console.log('Deploying graph on LensFactory');

    let ownerAddress = await ownerWallet.getAddress();

    console.log('Owner:', ownerAddress);

    let tx = await (lensFactory.connect(ownerWallet) as Contract).deployGraph(
      'metadataURI',
      ownerAddress,
      [],
      [],
      []
    );

    // Search for event
    const txReceipt = (await tx.wait()) as ethers.TransactionReceipt;

    // console.log('txReceipt:', txReceipt);

    let configuredEventFound = false;
    let reconfiguredEventFound = false;

    txReceipt.logs.forEach((log) => {
      log.topics.forEach((topic) => {
        if (topic === '0xe31b7f6ac48cc37d54695e01ec6a1cb51ddad7bc08abbf00c0f31eec1421ddc7') {
          console.warn('Rule Configured event found');
          configuredEventFound = true;
        } else if (topic === '0x63db4eb96afe8985b402c9b78b88f2fe607f1052bf71da6eea9e1fee464382ca') {
          console.warn('Rule Re-Configured event found');
          reconfiguredEventFound = true;
        }
      });
    });

    expect(configuredEventFound).to.be.true;
    expect(reconfiguredEventFound).to.be.false;
  });
});
