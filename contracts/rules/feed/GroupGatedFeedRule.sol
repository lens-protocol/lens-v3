// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";

/// @custom:keccak lens.param.group
bytes32 constant PARAM__GROUP = 0xa92ea569d1a9f915f96759ba7cea5f135d011c442b0508dbef76a309e55f4458;

contract GroupGatedFeedRule is IFeedRule, MetadataBased {
    event Lens_Rule_MetadataURISet(string metadataURI);

    mapping(address => mapping(bytes32 => address)) internal _groupGate;

    constructor(string memory metadataURI) {
        _setMetadataURI(metadataURI);
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Rule_MetadataURISet(metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        address groupGate;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__GROUP) {
                groupGate = abi.decode(ruleParams[i].value, (address));
            }
        }
        _groupGate[msg.sender][configSalt] = groupGate;
        IGroup(groupGate).isMember(address(this)); // Aims to verify the provided address is a valid group
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256, /* postId */
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        require(IGroup(_groupGate[msg.sender][configSalt]).isMember(postParams.author), "NotAMember()");
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function processRemovePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert();
    }
}
