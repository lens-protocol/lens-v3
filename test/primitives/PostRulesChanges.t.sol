// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../helpers/TypeHelpers.sol";
import {IFeed, CreatePostParams, EditPostParams} from "@core/interfaces/IFeed.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {RulesTest} from "test/primitives/rules/Rules.t.sol";
import {MockAccessControl} from "test/mocks/MockAccessControl.sol";
import {Rule} from "@core/types/Types.sol";
import {IPostRule} from "@core/interfaces/IPostRule.sol";
import {RuleExecutionTest} from "test/primitives/rules/RuleExecution.t.sol";

contract PostRulesChangesTest is RulesTest, BaseDeployments, RuleExecutionTest {
    address feedForRules;
    MockAccessControl mockAccessControl;

    uint256 postId;

    function setUp() public virtual override(RulesTest, BaseDeployments, RuleExecutionTest) {
        BaseDeployments.setUp();

        mockAccessControl = new MockAccessControl();

        vm.prank(address(lensFactory));
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
        RuleExecutionTest.setUp();
    }

    function test_Cannot_ChangeRules_IfNotHasAccessToChangeRulesPid() public override(RulesTest) {}

    function _changeRules(RuleChange[] memory ruleChanges) internal override(RulesTest, RuleExecutionTest) {
        IFeed(feedForRules).changePostRules(postId, ruleChanges, _emptyRuleProcessingParamsArray());
    }

    function _primitiveAddress() internal view override returns (address) {
        return feedForRules;
    }

    function _aValidRuleSelector() internal pure override returns (bytes4) {
        return IPostRule.processCreatePost.selector;
    }

    function _configureRuleSelector() internal pure override(RulesTest, RuleExecutionTest) returns (bytes4) {
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

    function _generatePostId(address _feed, address _author, uint256 _authorPostSequentialId)
        internal
        view
        returns (uint256)
    {
        return uint256(keccak256(abi.encode("evm:", block.chainid, address(_feed), _author, _authorPostSequentialId)));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function testRuleExecution_CreatePostEntityRules(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IPostRule.processCreatePost.selector;
        bytes memory executionFunctionCallData = abi.encodeCall(
            IFeed.createPost,
            (
                CreatePostParams({
                    author: makeAddr("OTHER_AUTHOR"),
                    contentURI: "ipfs://content",
                    repostedPostId: 0,
                    quotedPostId: 0,
                    repliedPostId: postId,
                    ruleChanges: _emptyRuleChangeArray(),
                    extraData: _emptyKeyValueArray()
                }),
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            )
        );

        uint256 expectedReplyPostId = _generatePostId(address(feedForRules), makeAddr("OTHER_AUTHOR"), 1);

        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IPostRule.processCreatePost,
            (
                bytes32(uint256(1)),
                postId,
                expectedReplyPostId,
                CreatePostParams({
                    author: makeAddr("OTHER_AUTHOR"),
                    contentURI: "ipfs://content",
                    repostedPostId: 0,
                    quotedPostId: 0,
                    repliedPostId: postId,
                    ruleChanges: _emptyRuleChangeArray(),
                    extraData: _emptyKeyValueArray()
                }),
                _emptyKeyValueArray(),
                _emptyKeyValueArray()
            )
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(feedForRules),
            executionFunctionCallData,
            makeAddr("OTHER_AUTHOR"),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }

    function testRuleExecution_EditPostEntityRules(
        bool mandatory1_passes,
        bool mandatory2_passes,
        bool optional1_passes,
        bool optional2_passes
    ) public {
        bytes4 executionSelector = IPostRule.processEditPost.selector;

        vm.prank(makeAddr("OTHER_AUTHOR"));
        uint256 replyPostId = IFeed(feedForRules).createPost({
            postParams: CreatePostParams({
                author: makeAddr("OTHER_AUTHOR"),
                contentURI: "ipfs://content",
                repostedPostId: 0,
                quotedPostId: 0,
                repliedPostId: postId,
                ruleChanges: _emptyRuleChangeArray(),
                extraData: _emptyKeyValueArray()
            }),
            customParams: _emptyKeyValueArray(),
            feedRulesParams: _emptyRuleProcessingParamsArray(),
            rootPostRulesParams: _emptyRuleProcessingParamsArray(),
            quotedPostRulesParams: _emptyRuleProcessingParamsArray()
        });

        bytes memory executionFunctionCallData = abi.encodeCall(
            IFeed.editPost,
            (
                replyPostId,
                EditPostParams({contentURI: "ipfs://content_updated", extraData: _emptyKeyValueArray()}),
                _emptyKeyValueArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray(),
                _emptyRuleProcessingParamsArray()
            )
        );

        bytes memory expectedRuleExecutionCallData = abi.encodeCall(
            IPostRule.processEditPost,
            (
                bytes32(uint256(1)),
                postId,
                replyPostId,
                EditPostParams({contentURI: "ipfs://content_updated", extraData: _emptyKeyValueArray()}),
                _emptyKeyValueArray(),
                _emptyKeyValueArray()
            )
        );
        _verifyRulesExecution(
            executionSelector,
            expectedRuleExecutionCallData,
            address(feedForRules),
            executionFunctionCallData,
            makeAddr("OTHER_AUTHOR"),
            mandatory1_passes,
            mandatory2_passes,
            optional1_passes,
            optional2_passes
        );
    }
}
