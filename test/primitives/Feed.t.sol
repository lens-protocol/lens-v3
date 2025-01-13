// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {OwnerAdminOnlyAccessControl} from "@extensions/access/OwnerAdminOnlyAccessControl.sol";
import "../helpers/TypeHelpers.sol";
import {Feed} from "@core/primitives/feed/Feed.sol";
import {IFeed, CreatePostParams, EditPostParams} from "@core/interfaces/IFeed.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {IFeedRule} from "@core/interfaces/IFeedRule.sol";
import {Rule} from "@core/types/Types.sol";

contract FeedTest is RulesTest, BaseDeployments {
    IFeed feed;

    address feedForRules;
    MockAccessControl mockAccessControl;

    address author = makeAddr("AUTHOR");
    address feedOwner = makeAddr("FEED_OWNER");

    function setUp() public virtual override(RulesTest, BaseDeployments) {
        BaseDeployments.setUp();

        feed = IFeed(
            lensFactory.deployFeed({
                metadataURI: "some metadata uri",
                owner: author,
                admins: _emptyAddressArray(),
                rules: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            })
        );

        mockAccessControl = new MockAccessControl();

        feedForRules = feedFactory.deployFeed({
            metadataURI: "uri://feed",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        RulesTest.setUp();
    }

    function testPost() public {
        vm.prank(author);
        uint256 postId = feed.createPost({
            postParams: CreatePostParams({
                author: author,
                contentURI: "some content uri",
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

        vm.prank(author);
        feed.editPost({
            postId: postId,
            postParams: EditPostParams({contentURI: "some new content uri", extraData: _emptyKeyValueArray()}),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        vm.prank(author);
        feed.deletePost({
            postId: postId,
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray()
        });
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _changeRules(RuleChange[] memory ruleChanges) internal override {
        IFeed(feedForRules).changeFeedRules(ruleChanges);
    }

    function _primitiveAddress() internal view override returns (address) {
        return feedForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IFeedRule.processCreatePost.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IFeedRule.processCreatePost.selector;
        selectors[1] = IFeedRule.processEditPost.selector;
        selectors[2] = IFeedRule.processRemovePost.selector;
        selectors[3] = IFeedRule.processPostRuleChanges.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IFeed(feedForRules).getFeedRules(selector, required);
    }
}
