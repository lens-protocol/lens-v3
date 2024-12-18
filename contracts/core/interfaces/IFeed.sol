// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue, Rule, RuleProcessingParams, RuleSelectorChange, RuleConfigurationChange} from "./../types/Types.sol";
import {IMetadataBased} from "./../interfaces/IMetadataBased.sol";

struct EditPostParams {
    string contentURI;
    KeyValue[] extraData;
}

struct CreatePostParams {
    address author; // Multiple authors can be added in extraData
    string contentURI;
    uint256 repostedPostId;
    uint256 quotedPostId;
    uint256 repliedPostId;
    RuleConfigurationChange[] configChanges;
    RuleSelectorChange[] selectorChanges;
    KeyValue[] extraData;
}

// This is a return type (for getters)
struct Post {
    address author;
    uint256 authorPostSequentialId;
    uint256 postSequentialId;
    string contentURI;
    uint256 rootPostId;
    uint256 repostedPostId;
    uint256 quotedPostId;
    uint256 repliedPostId;
    uint80 creationTimestamp;
    address creationSource;
    uint80 lastUpdatedTimestamp;
    address lastUpdateSource;
}

interface IFeed is IMetadataBased {
    event Lens_Feed_PostCreated(
        uint256 indexed postId,
        address indexed author,
        uint256 localSequentialId,
        uint256 rootPostId,
        CreatePostParams postParams,
        KeyValue[] customParams,
        RuleProcessingParams[] feedRulesParams,
        RuleProcessingParams[] rootPostRulesParams,
        RuleProcessingParams[] quotedPostRulesParams,
        address indexed source
    );

    event Lens_Feed_PostEdited(
        uint256 indexed postId,
        address indexed author,
        EditPostParams newPostParams,
        KeyValue[] customParams,
        RuleProcessingParams[] feedRulesParams,
        RuleProcessingParams[] rootPostRulesParams,
        RuleProcessingParams[] quotedPostRulesParams,
        address indexed source
    );

    event Lens_Feed_PostRemoved(
        uint256 indexed postId, address indexed author, KeyValue[] customParams, address indexed source
    );

    event Lens_Feed_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Feed_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Feed_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Feed_RuleConfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Feed_RuleReconfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Feed_RuleSelectorEnabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Feed_RuleSelectorDisabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Feed_Post_RuleConfigured(
        uint256 indexed postId, address author, address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams
    );

    event Lens_Feed_Post_RuleReconfigured(
        uint256 indexed postId, address author, address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams
    );

    event Lens_Feed_Post_RuleSelectorEnabled(
        uint256 indexed postId,
        address author,
        address indexed rule,
        bytes32 indexed configSalt,
        bool isRequired,
        bytes4 ruleSelector
    );

    event Lens_Feed_Post_RuleSelectorDisabled(
        uint256 indexed postId,
        address author,
        address indexed rule,
        bytes32 indexed configSalt,
        bool isRequired,
        bytes4 ruleSelector
    );

    event Lens_Feed_Post_ExtraDataAdded(
        uint256 indexed postId, bytes32 indexed key, bytes value, bytes indexed valueIndexed
    );
    event Lens_Feed_Post_ExtraDataUpdated(
        uint256 indexed postId, bytes32 indexed key, bytes value, bytes indexed valueIndexed
    );
    event Lens_Feed_Post_ExtraDataRemoved(uint256 indexed postId, bytes32 indexed key);

    event Lens_Feed_MetadataURISet(string metadataURI);

    function changeFeedRules(
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges
    ) external;

    function createPost(
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams,
        RuleProcessingParams[] calldata rootPostRulesParams,
        RuleProcessingParams[] calldata quotedPostRulesParams
    ) external returns (uint256);

    function editPost(
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams,
        RuleProcessingParams[] calldata rootPostRulesParams,
        RuleProcessingParams[] calldata quotedPostRulesParams
    ) external;

    // "Delete" - u know u cannot delete stuff from the internet, right? :]
    // But this will at least remove it from the current state, so contracts accessing it will know.
    // TODO: Debate post deletion, soft vs. hard delete, extra data deletion, etc.
    function removePost(
        uint256 postId,
        bytes32[] calldata extraDataKeysToRemove,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams
    ) external;

    function changePostRules(
        uint256 postId,
        RuleConfigurationChange[] calldata configChanges,
        RuleSelectorChange[] calldata selectorChanges,
        RuleProcessingParams[] calldata feedRulesParams
    ) external;

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    // Getters

    function getPost(uint256 postId) external view returns (Post memory);

    function getPostAuthor(uint256 postId) external view returns (address);

    function getFeedRules(bytes4 ruleSelector, bool isRequired) external view returns (Rule[] memory);

    function getPostRules(bytes4 ruleSelector, uint256 postId, bool isRequired) external view returns (Rule[] memory);

    function getPostCount() external view returns (uint256);

    function getPostCount(address author) external view returns (uint256);

    function getPostExtraData(uint256 postId, bytes32 key) external view returns (bytes memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);

    function getPostSequentialId(uint256 postId) external view returns (uint256);

    function getAuthorPostSequentialId(uint256 postId) external view returns (uint256);

    function getNextPostId(address author) external view returns (uint256);

    // TODO: Should we have getPostBySequentialId and getPostByAuthorSequentialId ?
}