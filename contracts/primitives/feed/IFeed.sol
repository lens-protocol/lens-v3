// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataElement, RuleConfiguration, RuleExecutionData} from "../../types/Types.sol";
import {IMetadataBased} from "./../base/IMetadataBased.sol";

// TODO: Discuss if there's a need for anything else to be added here
struct EditPostParams {
    string contentURI;
    DataElement[] extraData;
}

struct CreatePostParams {
    address author; // Multiple authors can be added in extraData
    address source; // Client source, if any
    string contentURI;
    uint256 quotedPostId;
    uint256 parentPostId;
    RuleConfiguration[] rules;
    RuleExecutionData feedRulesData;
    RuleExecutionData changeRulesQuotePostRulesData;
    RuleExecutionData changeRulesParentPostRulesData;
    RuleExecutionData quotesPostRulesData;
    RuleExecutionData parentsPostRulesData;
    DataElement[] extraData;
}

struct CreateRepostParams {
    address author;
    address source;
    uint256 parentPostId;
    RuleExecutionData feedRulesData;
    RuleExecutionData parentsPostRulesData;
    DataElement[] extraData;
}

// This is a return type (for getters)
struct Post {
    address author;
    uint256 localSequentialId;
    address source;
    string contentURI;
    bool isRepost;
    uint256 quotedPostId;
    uint256 parentPostId;
    address[] requiredRules;
    address[] anyOfRules;
    uint80 creationTimestamp;
    uint80 lastUpdatedTimestamp;
}

interface IFeed is IMetadataBased {
    event Lens_Feed_PostCreated(
        uint256 indexed postId,
        address indexed author,
        uint256 indexed localSequentialId,
        CreatePostParams postParams,
        uint256 rootPostId
    );

    event Lens_Feed_RepostCreated(
        uint256 indexed postId,
        address indexed author,
        uint256 indexed localSequentialId,
        CreateRepostParams postParams,
        uint256 rootPostId
    );

    event Lens_Feed_PostEdited(
        uint256 indexed postId, address indexed author, EditPostParams newPostParams, RuleExecutionData feedRulesData
    );

    event Lens_Feed_PostDeleted(uint256 indexed postId, address indexed author, RuleExecutionData feedRulesData);

    event Lens_Feed_ExtraDataSet(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Feed_RuleAdded(address indexed ruleAddress, bytes configData, bool indexed isRequired);
    event Lens_Feed_RuleUpdated(address indexed ruleAddress, bytes configData, bool indexed isRequired);
    event Lens_Feed_RuleRemoved(address indexed ruleAddress);

    event Lens_Feed_Post_RuleAdded(
        uint256 indexed postId, address indexed author, address indexed ruleAddress, bytes configData, bool isRequired
    );
    event Lens_Feed_Post_RuleUpdated(
        uint256 indexed postId, address indexed author, address indexed ruleAddress, bytes configData, bool isRequired
    );
    event Lens_Feed_Post_RuleRemoved(uint256 indexed postId, address indexed author, address indexed ruleAddress);

    event Lens_Feed_MetadataURISet(string metadataURI);

    function addFeedRules(RuleConfiguration[] calldata rules) external;

    function updateFeedRules(RuleConfiguration[] calldata rules) external;

    function removeFeedRules(address[] calldata rules) external;

    function createPost(CreatePostParams calldata postParams) external returns (uint256);

    function createRepost(CreateRepostParams calldata repostParams) external returns (uint256);

    function editPost(
        uint256 postId,
        EditPostParams calldata newPostParams,
        RuleExecutionData calldata editPostFeedRulesData
    ) external;

    // "Delete" - u know u cannot delete stuff from the internet, right? :]
    // But this will at least remove it from the current state, so contracts accesing it will know.
    function deletePost(
        uint256 postId,
        bytes32[] calldata extraDataKeysToDelete,
        RuleExecutionData calldata feedRulesData
    ) external;

    function addPostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData,
        RuleExecutionData calldata quotePostRulesData,
        RuleExecutionData calldata parentPostRulesData
    ) external;

    function updatePostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData,
        RuleExecutionData calldata quotePostRulesData,
        RuleExecutionData calldata parentPostRulesData
    ) external;

    function removePostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData,
        RuleExecutionData calldata quotePostRulesData,
        RuleExecutionData calldata parentPostRulesData
    ) external;

    function setExtraData(DataElement[] calldata extraDataToSet) external;

    // Getters

    function getPost(uint256 postId) external view returns (Post memory);

    function getPostAuthor(uint256 postId) external view returns (address);

    function getFeedRules(bool isRequired) external view returns (address[] memory);

    function getPostRules(uint256 postId, bool isRequired) external view returns (address[] memory);

    function getPostCount() external view returns (uint256);

    function getPostExtraData(uint256 postId, bytes32 key) external view returns (bytes memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
