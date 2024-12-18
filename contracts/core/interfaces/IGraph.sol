// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {RuleProcessingParams, KeyValue, RuleChange, Rule} from "./../types/Types.sol";
import {IMetadataBased} from "./IMetadataBased.sol";

// TODO: Might worth to add extraData to the follow entity
// Maybe it requires a targetExtraData and a followerExtraData
// so then you have different auth for them, and they store different data
// e.g. the follower can store a label/tag/category, like "I follow this account because of crypto/politics/etc"
// and the target can store other information like tiers, etc.
struct Follow {
    uint256 id;
    uint256 timestamp;
}

interface IGraph is IMetadataBased {
    event Lens_Graph_RuleConfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Graph_RuleReconfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Graph_RuleSelectorEnabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_RuleSelectorDisabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_Follow_RuleConfigured(
        address indexed account, address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams
    );

    event Lens_Graph_Follow_RuleReconfigured(
        address indexed account, address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams
    );

    event Lens_Graph_Follow_RuleSelectorEnabled(
        address indexed account, address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_Follow_RuleSelectorDisabled(
        address indexed account, address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_Followed(
        address indexed followerAccount,
        address indexed accountToFollow,
        uint256 followId,
        KeyValue[] customParams,
        RuleProcessingParams[] graphRulesProcessingParams,
        RuleProcessingParams[] followRulesProcessingParams,
        address indexed source
    );

    event Lens_Graph_Unfollowed(
        address indexed followerAccount,
        address indexed accountToUnfollow,
        uint256 followId,
        KeyValue[] customParams,
        RuleProcessingParams[] graphRulesProcessingParams,
        address indexed source
    );

    event Lens_Graph_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Graph_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Graph_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Graph_MetadataURISet(string metadataURI);

    function changeGraphRules(RuleChange[] calldata ruleChanges) external;

    function changeFollowRules(
        address account,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external;

    function follow(
        address followerAccount,
        address targetAccount,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams,
        RuleProcessingParams[] calldata followRulesProcessingParams
    ) external returns (uint256);

    function unfollow(
        address followerAccount,
        address targetAccount,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external returns (uint256);

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    // Getters

    function isFollowing(address followerAccount, address targetAccount) external view returns (bool);

    function getFollowerById(address account, uint256 followId) external view returns (address);

    function getFollow(address followerAccount, address followedAccount) external view returns (Follow memory);

    function getFollowersCount(address account) external view returns (uint256);

    function getFollowingCount(address account) external view returns (uint256);

    function getGraphRules(bytes4 ruleSelector, bool isRequired) external view returns (Rule[] memory);

    function getFollowRules(
        address account,
        bytes4 ruleSelector,
        bool isRequired
    ) external view returns (Rule[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
