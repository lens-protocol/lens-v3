import { Contract, Wallet } from 'zksync-ethers';
import { deployContract, getWallet, LOCAL_RICH_WALLETS } from '../../deploy/utils';
import { ethers } from 'ethers';
import { expect } from 'chai';

describe('Account', function () {
  let ownerWallet: Wallet;
  let lensFactory: Contract;
  let accountBlockingRule: Contract;
  let groupGatedFeedRule: Contract;
  let usernameSimpleCharsetNamespaceRule: Contract;

  before(async function () {
    ownerWallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    console.log('Owner:', await ownerWallet.getAddress());

    // Global Rules for primitives

    accountBlockingRule = await deployContract('AccountBlockingRule', [ownerWallet.address, 'uri://any'], {
      wallet: ownerWallet,
      silent: true,
    });
    let accountBlockingRuleAddress = await accountBlockingRule.getAddress();
    console.log('AccountBlockingRule:', accountBlockingRuleAddress);

    groupGatedFeedRule = await deployContract('GroupGatedFeedRule', [ownerWallet.address, 'uri://any'], {
      wallet: ownerWallet,
      silent: true,
    });
    let groupGatedFeedRuleAddress = await groupGatedFeedRule.getAddress();
    console.log('GroupGatedFeedRule:', groupGatedFeedRuleAddress);

    usernameSimpleCharsetNamespaceRule = await deployContract('UsernameSimpleCharsetNamespaceRule', [ownerWallet.address, 'uri://any'], {
      wallet: ownerWallet,
      silent: true,
    });
    let usernameSimpleCharsetNamespaceRuleAddress = await usernameSimpleCharsetNamespaceRule.getAddress();
    console.log('UsernameSimpleCharsetNamespaceRule:', usernameSimpleCharsetNamespaceRuleAddress);

    // Proxy stuff

    const proxyAdminLock = await deployContract('Lock', [await ownerWallet.getAddress(), true], {
      wallet: ownerWallet,
      silent: true,
    });

    const appImplementation = await deployContract('App', [], {
      wallet: ownerWallet,
      silent: true,
    });
    const accountImplementation = await deployContract('Account', [], {
      wallet: ownerWallet,
      silent: true,
    });
    const feedImplementation = await deployContract('Feed', [], {
      wallet: ownerWallet,
      silent: true,
    });
    const graphImplementation = await deployContract('Graph', [], {
      wallet: ownerWallet,
      silent: true,
    });
    const groupImplementation = await deployContract('Group', [], {
      wallet: ownerWallet,
      silent: true,
    });
    const namespaceImplementation = await deployContract('Namespace', [], {
      wallet: ownerWallet,
      silent: true,
    });

    const appBeacon = await deployContract(
      'Beacon',
      [await ownerWallet.getAddress(), 1, await appImplementation.getAddress()],
      { wallet: ownerWallet, silent: true }
    );
    const accountBeacon = await deployContract(
      'Beacon',
      [await ownerWallet.getAddress(), 1, await accountImplementation.getAddress()],
      { wallet: ownerWallet, silent: true }
    );
    const feedBeacon = await deployContract(
      'Beacon',
      [await ownerWallet.getAddress(), 1, await feedImplementation.getAddress()],
      { wallet: ownerWallet, silent: true }
    );
    const graphBeacon = await deployContract(
      'Beacon',
      [await ownerWallet.getAddress(), 1, await graphImplementation.getAddress()],
      { wallet: ownerWallet, silent: true }
    );
    const groupBeacon = await deployContract(
      'Beacon',
      [await ownerWallet.getAddress(), 1, await groupImplementation.getAddress()],
      { wallet: ownerWallet, silent: true }
    );
    const namespaceBeacon = await deployContract(
      'Beacon',
      [await ownerWallet.getAddress(), 1, await namespaceImplementation.getAddress()],
      { wallet: ownerWallet, silent: true }
    );

    // Extension primitives

    let accessControlFactoryAddress = await (
      await deployContract('AccessControlFactory', [], { wallet: ownerWallet, silent: true })
    ).getAddress();
    console.log('AccessControlFactory:', accessControlFactoryAddress);

    // Upgradeable extension factories

    let accountFactoryAddress = await (
      await deployContract(
        'AccountFactory',
        [await accountBeacon.getAddress(), await proxyAdminLock.getAddress()],
        { wallet: ownerWallet, silent: true }
      )
    ).getAddress();
    console.log('AccountFactory:', accountFactoryAddress);

    let appFactoryAddress = await (
      await deployContract(
        'AppFactory',
        [await appBeacon.getAddress(), await proxyAdminLock.getAddress()],
        { wallet: ownerWallet, silent: true }
      )
    ).getAddress();
    console.log('AppFactory:', appFactoryAddress);

    // Main primitives factories

    let feedFactoryAddress = await (
      await deployContract(
        'FeedFactory',
        [await feedBeacon.getAddress(), await proxyAdminLock.getAddress()],
        { wallet: ownerWallet, silent: true }
      )
    ).getAddress();
    console.log('FeedFactory:', feedFactoryAddress);
    let graphFactoryAddress = await (
      await deployContract(
        'GraphFactory',
        [await graphBeacon.getAddress(), await proxyAdminLock.getAddress()],
        { wallet: ownerWallet, silent: true }
      )
    ).getAddress();
    console.log('GraphFactory:', graphFactoryAddress);
    let groupFactoryAddress = await (
      await deployContract(
        'GroupFactory',
        [await groupBeacon.getAddress(), await proxyAdminLock.getAddress()],
        { wallet: ownerWallet, silent: true }
      )
    ).getAddress();
    console.log('GroupFactory:', groupFactoryAddress);
    let namespaceFactoryAddress = await (
      await deployContract(
        'NamespaceFactory',
        [await namespaceBeacon.getAddress(), await proxyAdminLock.getAddress()],
        { wallet: ownerWallet, silent: true }
      )
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
        usernameSimpleCharsetNamespaceRuleAddress
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
