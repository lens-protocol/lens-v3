// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {LensFactory, CreateAccountParams, CreateUsernameParams} from "@extensions/factories/LensFactory.sol";
import {AccountFactory} from "@extensions/factories/AccountFactory.sol";
import {AppFactory} from "@extensions/factories/AppFactory.sol";
import {GroupFactory} from "@extensions/factories/GroupFactory.sol";
import {FeedFactory} from "@extensions/factories/FeedFactory.sol";
import {GraphFactory} from "@extensions/factories/GraphFactory.sol";
import {NamespaceFactory} from "@extensions/factories/NamespaceFactory.sol";
import {Namespace} from "@core/primitives/namespace/Namespace.sol";
import {RuleChange, KeyValue} from "@core/types/Types.sol";
import {AccountManagerPermissions} from "@extensions/account/Account.sol";
import {AccessControlFactory} from "@extensions/factories/AccessControlFactory.sol";
import {AccountBlockingRule} from "contracts/rules/AccountBlockingRule.sol";
import {IGraph} from "@core/interfaces/IGraph.sol";
import {GroupGatedFeedRule} from "contracts/rules/feed/GroupGatedFeedRule.sol";
import "test/helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {BaseSource} from "contracts/core/base/BaseSource.sol";
import {SourceStamp} from "contracts/core/types/Types.sol";
import {ISource} from "contracts/core/interfaces/ISource.sol";
import {AppInitialProperties} from "contracts/extensions/primitives/app/App.sol";
import {INamespace} from "contracts/core/interfaces/INamespace.sol";
import {IFeed, CreatePostParams} from "contracts/core/interfaces/IFeed.sol";

// contract MockSource is BaseSource {
//     function validateSource(SourceStamp calldata sourceStamp) external override {
//         // do nothing
//     }

//     function getTreasury() external view returns (address) {
//         return address(this);
//     }

//     function _isValidSourceStampSigner(address signer) internal override returns (bool) {
//         return true;
//     }
// }

contract EventsTest is Test, BaseDeployments {
    address mockSource;

    function setUp() public override {
        super.setUp();
        // mockSource = address(new MockSource());
    }

    function testEvents() public {
        address feed = lensFactory.deployFeed({
            metadataURI: "uri://any",
            owner: address(this),
            admins: _emptyAddressArray(),
            rules: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        address namespace = lensFactory.deployNamespace({
            namespace: "bitcoin",
            metadataURI: "satoshi://nakamoto",
            owner: address(this),
            admins: new address[](0),
            rules: new RuleChange[](0),
            extraData: new KeyValue[](0),
            nftName: "Bitcoin",
            nftSymbol: "BTC"
        });

        address graph = lensFactory.deployGraph({
            metadataURI: "uri://any",
            owner: address(this),
            admins: _emptyAddressArray(),
            rules: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        address app = lensFactory.deployApp({
            metadataURI: "uri://any",
            sourceStampVerificationEnabled: false,
            owner: address(this),
            admins: _emptyAddressArray(),
            initialProperties: AppInitialProperties({
                graph: graph,
                feeds: _toAddressArray(feed),
                namespace: namespace,
                groups: _emptyAddressArray(),
                defaultFeed: feed,
                signers: _emptyAddressArray(),
                paymaster: address(this),
                treasury: address(this)
            }),
            extraData: _emptyKeyValueArray()
        });

        INamespace(namespace).createUsername({
            account: address(this),
            username: "satoshi",
            customParams: _emptyKeyValueArray(),
            ruleProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        lensFactory.createAccountWithUsernameFree(
            namespace,
            CreateAccountParams({
                metadataURI: "uri://any",
                owner: address(this),
                accountManagers: _emptyAddressArray(),
                accountManagersPermissions: new AccountManagerPermissions[](0),
                accountCreationSourceStamp: SourceStamp({
                    source: app,
                    originalMsgSender: address(this), // TODO: Set proper value when testing source validation
                    validator: address(this), // TODO: Set proper value when testing source validation
                    nonce: 0,
                    deadline: block.timestamp + 1000,
                    signature: new bytes(0)
                }),
                accountExtraData: _emptyKeyValueArray()
            }),
            CreateUsernameParams({
                username: "notsatoshi",
                createUsernameCustomParams: _emptyKeyValueArray(),
                createUsernameRuleProcessingParams: _emptyRuleProcessingParamsArray(),
                assignUsernameCustomParams: _emptyKeyValueArray(),
                assignRuleProcessingParams: _emptyRuleProcessingParamsArray(),
                usernameExtraData: _emptyKeyValueArray()
            })
        );

        address follower = makeAddr("FOLLOWER");
        address target = makeAddr("TARGET");

        vm.prank(follower);
        IGraph(graph).follow({
            followerAccount: follower,
            accountToFollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            followRulesProcessingParams: _emptyRuleProcessingParamsArray(),
            extraData: _emptyKeyValueArray()
        });

        vm.prank(follower);
        IGraph(graph).unfollow({
            followerAccount: follower,
            accountToUnfollow: target,
            customParams: _emptyKeyValueArray(),
            graphRulesProcessingParams: _emptyRuleProcessingParamsArray()
        });

        IFeed(feed).createPost({
            postParams: CreatePostParams({
                author: address(this),
                contentURI: "content",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: 0,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    function onERC721Received(
        address, /* operator */
        address, /* from */
        uint256, /* tokenId */
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
