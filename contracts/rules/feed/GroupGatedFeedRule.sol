// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {CreatePostParams, EditPostParams} from "./../../core/interfaces/IFeed.sol";
import {IFeedRule} from "./../../core/interfaces/IFeedRule.sol";
import {RuleChange} from "./../../core/types/Types.sol";
import {IGroup} from "./../../core/interfaces/IGroup.sol";
import {KeyValue} from "./../../core/types/Types.sol";

contract GroupGatedFeedRule is IFeedRule {
    // keccak256("lens.param.key.group");
    bytes32 immutable GROUP_PARAM_KEY = 0xe556a4384e8a110aab4ea745eff2c09de81f87f56e4ecba2205982230d3bd4f4;

    mapping(address => mapping(bytes4 => mapping(bytes32 => address))) internal _groupGate;

    function configure(bytes4 ruleSelector, bytes32 salt, KeyValue[] calldata ruleConfigurationParams) external {
        require(ruleSelector == this.processCreatePost.selector);
        address groupGate;
        for (uint256 i = 0; i < ruleConfigurationParams.length; i++) {
            if (ruleConfigurationParams[i].key == GROUP_PARAM_KEY) {
                groupGate = abi.decode(ruleConfigurationParams[i].value, (address));
            }
        }
        _groupGate[msg.sender][ruleSelector][salt] = groupGate;
        IGroup(groupGate).getMembershipId(address(this));
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256, /* postId */
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external view override {
        require(
            IGroup(_groupGate[msg.sender][this.processCreatePost.selector][configSalt]).getMembershipId(
                postParams.author
            ) != 0,
            "NotAMember()"
        );
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    function processRemovePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveCustomParams */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleExecutionParams */
    ) external pure override {
        revert();
    }
}
