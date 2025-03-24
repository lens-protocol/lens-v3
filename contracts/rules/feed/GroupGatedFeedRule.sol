// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {CreatePostParams, EditPostParams} from "contracts/core/interfaces/IFeed.sol";
import {IFeedRule} from "contracts/core/interfaces/IFeedRule.sol";
import {IGroup} from "contracts/core/interfaces/IGroup.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {KeyValue, RuleChange} from "contracts/core/types/Types.sol";
import {OwnableMetadataBasedRule} from "contracts/rules/base/OwnableMetadataBasedRule.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

/// @custom:keccak lens.param.group
bytes32 constant PARAM__GROUP = 0xa92ea569d1a9f915f96759ba7cea5f135d011c442b0508dbef76a309e55f4458;
/// @custom:keccak lens.param.repliesRestricted
bytes32 constant PARAM__REPLIES_RESTRICTED = 0x4ce0155a596c1a9d5bcefb32cdbf357c849ac621a9b91d222b367cf53fe79a6f;
/// @custom:keccak lens.storage.GroupGatedFeedRule
bytes32 constant STORAGE__GROUP_GATED_FEED_RULE = 0xf4ecd2b7d1de7a29eac43757726b4a4fdd06e8b20a6cf006b5e3a936579b66d3;

contract GroupGatedFeedRule is IFeedRule, OwnableMetadataBasedRule, Initializable {
    struct Configuration {
        address groupGate;
        bool repliesRestricted;
    }

    struct Storage {
        mapping(address feed => mapping(bytes32 configSalt => Configuration config)) configuration;
    }

    function $storage() private pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__GROUP_GATED_FEED_RULE
        }
    }

    constructor() OwnableMetadataBasedRule(address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedRule._initialize(owner, metadataURI);
    }

    function configure(bytes32 configSalt, KeyValue[] calldata ruleParams) external override {
        Configuration memory configuration;
        // Restrict replies by default
        configuration.repliesRestricted = true;
        for (uint256 i = 0; i < ruleParams.length; i++) {
            if (ruleParams[i].key == PARAM__GROUP) {
                configuration.groupGate = abi.decode(ruleParams[i].value, (address));
            } else if (ruleParams[i].key == PARAM__REPLIES_RESTRICTED) {
                configuration.repliesRestricted = abi.decode(ruleParams[i].value, (bool));
            }
        }
        IGroup(configuration.groupGate).isMember(address(this)); // Aims to verify the provided address is a valid group
        $storage().configuration[msg.sender][configSalt] = configuration;
    }

    function processCreatePost(
        bytes32 configSalt,
        uint256, /* postId */
        CreatePostParams calldata postParams,
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external view override {
        Configuration memory configuration = $storage().configuration[msg.sender][configSalt];
        if (_shouldRestrictionBeApplied(configuration, postParams)) {
            require(IGroup(configuration.groupGate).isMember(postParams.author), Errors.NotAMember());
        }
    }

    function _shouldRestrictionBeApplied(Configuration memory configuration, CreatePostParams calldata postParams)
        internal
        pure
        returns (bool)
    {
        if (postParams.repliedPostId != 0) {
            return configuration.repliesRestricted;
        } else {
            return true;
        }
    }

    function processEditPost(
        bytes32, /* configSalt */
        uint256, /* postId */
        EditPostParams calldata, /* postParams */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processDeletePost(
        bytes32, /* configSalt */
        uint256, /* postId */
        KeyValue[] calldata, /* primitiveParams */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }

    function processPostRuleChanges(
        bytes32, /* configSalt */
        uint256, /* postId */
        RuleChange[] calldata, /* ruleChanges */
        KeyValue[] calldata /* ruleParams */
    ) external pure override {
        revert Errors.NotImplemented();
    }
}
