// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {
    LensFactory,
    CreateAccountParams,
    CreateUsernameParams,
    GroupWithFeed_GroupParams,
    GroupWithFeed_FeedParams
} from "@extensions/factories/LensFactory.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import {RuleChange, KeyValue} from "@core/types/Types.sol";
import {IGraph} from "@core/interfaces/IGraph.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {IGroup} from "@core/interfaces/IGroup.sol";
import {IGroupRule} from "@core/interfaces/IGroupRule.sol";
import {IAccount} from "@extensions/account/Account.sol";
import {IFeed} from "@core/interfaces/IFeed.sol";
import {IFeedRule} from "@core/interfaces/IFeedRule.sol";
import {Errors} from "@core/types/Errors.sol";

contract LensFactoryTest is Test, BaseDeployments {
    Namespace namespace;

    address ownerAccount;

    function setUp() public override {
        super.setUp();
        ownerAccount = lensFactory.deployAccount({
            metadataURI: "uri://any",
            owner: address(this),
            accountManagers: _emptyAddressArray(),
            accountManagersPermissions: _emptyAccountManagerPermissionsArray(),
            sourceStamp: _emptySourceStamp(),
            extraData: _emptyKeyValueArray()
        });
        namespace = Namespace(
            lensFactory.deployNamespace({
                namespace: "bitcoin",
                metadataURI: "satoshi://nakamoto",
                owner: address(this),
                admins: new address[](0),
                rules: new RuleChange[](0),
                extraData: new KeyValue[](0),
                nftName: "Bitcoin",
                nftSymbol: "BTC"
            })
        );
    }

    function testCanDeployFeed() public {
        lensFactory.deployFeed({
            metadataURI: "uri://any",
            owner: address(this),
            admins: _emptyAddressArray(),
            rules: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function testCreateAccountWithUsernameFree() public {
        CreateAccountParams memory accountParams = CreateAccountParams({
            metadataURI: "someMetadataURI",
            owner: address(this),
            accountManagers: _emptyAddressArray(),
            accountManagersPermissions: _emptyAccountManagerPermissionsArray(),
            accountCreationSourceStamp: _emptySourceStamp(),
            accountExtraData: _emptyKeyValueArray()
        });
        CreateUsernameParams memory usernameParams = CreateUsernameParams({
            username: "satoshi",
            createUsernameCustomParams: _emptyKeyValueArray(),
            createUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            assignUsernameCustomParams: _emptyKeyValueArray(),
            assignRuleProcessingParams: _emptyRuleProcessingParamsArray(),
            usernameExtraData: _emptyKeyValueArray()
        });
        lensFactory.createAccountWithUsernameFree({
            accountParams: accountParams,
            namespacePrimitiveAddress: address(namespace),
            usernameParams: usernameParams
        });
    }

    function testGraphFollowWithFactorySetup() public {
        IGraph graph = IGraph(
            lensFactory.deployGraph({
                metadataURI: "uri://any",
                owner: address(this),
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );
        graph.follow({
            followerAccount: address(this),
            accountToFollow: address(0xc0ffee),
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });
    }

    function testDeployGroup() public {
        address group = abi.decode(
            IAccount(payable(ownerAccount)).executeTransaction(
                address(lensFactory),
                0,
                abi.encodeWithSelector(
                    LensFactory.deployGroup.selector,
                    "uri://group",
                    ownerAccount,
                    _emptyAddressArray(),
                    _emptyRuleChangeArray(),
                    _emptyKeyValueArray(),
                    address(0), // founding member...
                    _emptyKeyValueArray()
                )
            ),
            (address)
        );
        _assertGroupSetup(group);
    }

    function testCreateGroupWithFeed() public {
        (address group, address feed) = abi.decode(
            IAccount(payable(ownerAccount)).executeTransaction(
                address(lensFactory),
                0,
                abi.encodeCall(
                    LensFactory.createGroupWithFeed,
                    (
                        ownerAccount,
                        _emptyAddressArray(),
                        GroupWithFeed_GroupParams({
                            groupMetadataURI: "uri://group",
                            groupRules: _emptyRuleChangeArray(),
                            groupExtraData: _emptyKeyValueArray(),
                            groupFoundingMember: address(ownerAccount)
                        }),
                        GroupWithFeed_FeedParams({
                            feedMetadataURI: "uri://feed",
                            feedRules: _emptyRuleChangeArray(),
                            feedExtraData: _emptyKeyValueArray(),
                            allowNonMembersToReply: false
                        })
                    )
                )
            ),
            (address, address)
        );
        _assertGroupSetup_createGroupWithFeed(group);
        _assertFeedSetup_createGroupWithFeed(feed, group);
    }

    function testCreateGroupWithFeed_FailsToAddFoundingMemberThatIsNotMsgSender(address randomFoundingMember) public {
        vm.assume(randomFoundingMember != ownerAccount);
        vm.expectRevert(Errors.InvalidParameter.selector);
        IAccount(payable(ownerAccount)).executeTransaction(
            address(lensFactory),
            0,
            abi.encodeCall(
                LensFactory.createGroupWithFeed,
                (
                    ownerAccount,
                    _emptyAddressArray(),
                    GroupWithFeed_GroupParams({
                        groupMetadataURI: "uri://group",
                        groupRules: _emptyRuleChangeArray(),
                        groupExtraData: _emptyKeyValueArray(),
                        groupFoundingMember: address(randomFoundingMember)
                    }),
                    GroupWithFeed_FeedParams({
                        feedMetadataURI: "uri://feed",
                        feedRules: _emptyRuleChangeArray(),
                        feedExtraData: _emptyKeyValueArray(),
                        allowNonMembersToReply: false
                    })
                )
            )
        );
    }

    function _assertGroupSetup_createGroupWithFeed(address group) internal view {
        _assertGroupSetup(group);
    }

    function _assertFeedSetup_createGroupWithFeed(address feed, address /* group */ ) internal view {
        assertEq(IFeed(feed).getFeedRules(IFeedRule.processEditPost.selector, true).length, 0);
        assertEq(IFeed(feed).getFeedRules(IFeedRule.processEditPost.selector, false).length, 0);

        assertEq(IFeed(feed).getFeedRules(IFeedRule.processDeletePost.selector, true).length, 0);
        assertEq(IFeed(feed).getFeedRules(IFeedRule.processDeletePost.selector, false).length, 0);

        assertEq(IFeed(feed).getFeedRules(IFeedRule.processPostRuleChanges.selector, true).length, 0);
        assertEq(IFeed(feed).getFeedRules(IFeedRule.processPostRuleChanges.selector, false).length, 0);

        assertEq(IFeed(feed).getFeedRules(IFeedRule.processCreatePost.selector, true).length, 2);
        assertEq(IFeed(feed).getFeedRules(IFeedRule.processCreatePost.selector, false).length, 0);

        address accountBlockingRuleAddress;
        address groupGatedRuleAddress;
        KeyValue[] memory factoryRules = lensFactory.getRules();
        for (uint256 i = 0; i < factoryRules.length; i++) {
            if (factoryRules[i].key == keccak256("lens.address.AccountBlockingRule")) {
                accountBlockingRuleAddress = abi.decode(factoryRules[i].value, (address));
            } else if (factoryRules[i].key == keccak256("lens.address.GroupGatedFeedRule")) {
                groupGatedRuleAddress = abi.decode(factoryRules[i].value, (address));
            }
        }
        assertEq(
            IFeed(feed).getFeedRules(IFeedRule.processCreatePost.selector, true)[0].ruleAddress,
            accountBlockingRuleAddress
        );
        assertEq(
            IFeed(feed).getFeedRules(IFeedRule.processCreatePost.selector, true)[1].ruleAddress, groupGatedRuleAddress
        );
    }

    function _assertGroupSetup(address group) internal view {
        _assertProcessAdditionGroupRules(group);
        _assertProcessRemovalGroupRules(group);
        _assertProcessJoiningGroupRules(group);
        _assertProcessLeavingGroupRules(group);
    }

    function _assertProcessAdditionGroupRules(address group) internal view {
        assertEq(IGroup(group).getGroupRules(IGroupRule.processAddition.selector, true).length, 1);
        assertEq(IGroup(group).getGroupRules(IGroupRule.processAddition.selector, false).length, 0);
        address addRemovePidGroupRuleAddress;
        KeyValue[] memory factoryRules = lensFactory.getRules();
        for (uint256 i = 0; i < factoryRules.length; i++) {
            if (factoryRules[i].key == keccak256("lens.address.AdditionRemovalPidGroupRule")) {
                addRemovePidGroupRuleAddress = abi.decode(factoryRules[i].value, (address));
            }
        }
        assertEq(
            IGroup(group).getGroupRules(IGroupRule.processRemoval.selector, true)[0].ruleAddress,
            addRemovePidGroupRuleAddress
        );
    }

    function _assertProcessRemovalGroupRules(address group) internal view {
        assertEq(IGroup(group).getGroupRules(IGroupRule.processRemoval.selector, true).length, 1);
        assertEq(IGroup(group).getGroupRules(IGroupRule.processRemoval.selector, false).length, 0);
        address addRemovePidGroupRuleAddress;
        KeyValue[] memory factoryRules = lensFactory.getRules();
        for (uint256 i = 0; i < factoryRules.length; i++) {
            if (factoryRules[i].key == keccak256("lens.address.AdditionRemovalPidGroupRule")) {
                addRemovePidGroupRuleAddress = abi.decode(factoryRules[i].value, (address));
            }
        }
        assertEq(
            IGroup(group).getGroupRules(IGroupRule.processRemoval.selector, true)[0].ruleAddress,
            addRemovePidGroupRuleAddress
        );
    }

    function _assertProcessJoiningGroupRules(address group) internal view {
        assertEq(IGroup(group).getGroupRules(IGroupRule.processJoining.selector, true).length, 1);
        assertEq(IGroup(group).getGroupRules(IGroupRule.processJoining.selector, false).length, 0);
        address banMemberGroupRuleAddress;
        KeyValue[] memory factoryRules = lensFactory.getRules();
        for (uint256 i = 0; i < factoryRules.length; i++) {
            if (factoryRules[i].key == keccak256("lens.address.BanMemberGroupRule")) {
                banMemberGroupRuleAddress = abi.decode(factoryRules[i].value, (address));
            }
        }
        assertEq(
            IGroup(group).getGroupRules(IGroupRule.processJoining.selector, true)[0].ruleAddress,
            banMemberGroupRuleAddress
        );
    }

    function _assertProcessLeavingGroupRules(address group) internal view {
        assertEq(IGroup(group).getGroupRules(IGroupRule.processLeaving.selector, true).length, 0);
        assertEq(IGroup(group).getGroupRules(IGroupRule.processLeaving.selector, false).length, 0);
    }
}
