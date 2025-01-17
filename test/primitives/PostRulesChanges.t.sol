// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {IFeed, CreatePostParams} from "@core/interfaces/IFeed.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {Rule} from "@core/types/Types.sol";
import {IPostRule} from "@core/interfaces/IPostRule.sol";

contract PostRulesChangesTest is RulesTest, BaseDeployments {
    address feedForRules;
    MockAccessControl mockAccessControl;

    uint256 postId;

    function setUp() public virtual override(RulesTest, BaseDeployments) {
        BaseDeployments.setUp();

        mockAccessControl = new MockAccessControl();

        feedForRules = feedFactory.deployFeed({
            metadataURI: "uri://feed",
            accessControl: mockAccessControl,
            proxyAdminOwner: address(this),
            ruleChanges: _emptyRuleChangeArray(),
            extraData: _emptyKeyValueArray()
        });

        postId = IFeed(feedForRules).createPost({
            postParams: CreatePostParams({
                author: address(this),
                contentURI: "content://uri",
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

        RulesTest.setUp();
    }

    function test_Cannot_ChangeRules_IfNotHasAccessToChangeRulesPid() public override(RulesTest) {}

    function _changeRules(RuleChange[] memory ruleChanges) internal override {
        IFeed(feedForRules).changePostRules(postId, ruleChanges, _emptyRuleProcessingParamsArray());
    }

    function _primitiveAddress() internal view override returns (address) {
        return feedForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IPostRule.processCreatePost.selector;
    }

    function _configureRuleSelector() internal pure override returns (bytes4) {
        return IPostRule.configure.selector;
    }

    function _getPrimitiveSupportedRuleSelectors() internal virtual override returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = IPostRule.processCreatePost.selector;
        selectors[1] = IPostRule.processEditPost.selector;
        return selectors;
    }

    function _getPrimitiveRules(bytes4 selector, bool required) internal view virtual override returns (Rule[] memory) {
        return IFeed(feedForRules).getPostRules(selector, postId, required);
    }
}
