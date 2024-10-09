// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFeed, Post, EditPostParams, CreatePostParams, CreateRepostParams} from "./IFeed.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {DataElement} from "./../../types/Types.sol";
import {RuleBasedFeed} from "./RuleBasedFeed.sol";
import {AccessControlled} from "./../base/AccessControlled.sol";
import {RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";
import {Events} from "./../../types/Events.sol";

contract Feed is IFeed, RuleBasedFeed, AccessControlled {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_RID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant DELETE_POST_RID = uint256(keccak256("DELETE_POST"));

    constructor(string memory metadataURI, IAccessControl accessControl) AccessControlled(accessControl) {
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Feed_MetadataURISet(metadataURI);
        _emitRIDs();
        emit Events.Lens_Contract_Deployed("feed", "lens.feed", "feed", "lens.feed");
    }

    function _emitRIDs() internal override {
        super._emitRIDs();
        emit Lens_ResourceId_Available(SET_RULES_RID, "SET_RULES");
        emit Lens_ResourceId_Available(SET_METADATA_RID, "SET_METADATA");
        emit Lens_ResourceId_Available(SET_EXTRA_DATA_RID, "SET_EXTRA_DATA");
        emit Lens_ResourceId_Available(DELETE_POST_RID, "DELETE_POST");
    }

    // Access Controlled functions

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_RID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Feed_MetadataURISet(metadataURI);
    }

    function addFeedRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _addFeedRule(rules[i]);
            emit Lens_Feed_RuleAdded(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function updateFeedRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _updateFeedRule(rules[i]);
            emit Lens_Feed_RuleUpdated(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function removeFeedRules(address[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeFeedRule(rules[i]);
            emit Lens_Feed_RuleRemoved(rules[i]);
        }
    }

    // PostRules functions // TODO: Move these in a proper place later

    function addPostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData,
        RuleExecutionData calldata changeRulesQuotePostRulesData,
        RuleExecutionData calldata changeRulesParentPostRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(!Core.$storage().posts[postId].isRepost, "CANNOT_ADD_RULES_TO_REPOST");
        for (uint256 i = 0; i < rules.length; i++) {
            _addPostRule(postId, rules[i]);
            emit Lens_Feed_Post_RuleAdded(
                postId, author, rules[i].ruleAddress, rules[i].configData, rules[i].isRequired
            );
        }
        _processAllParentsRulesChildPostRulesChanged(
            postId, rules, changeRulesQuotePostRulesData, changeRulesParentPostRulesData
        );

        // Check the feed rules if it accepts the new RuleConfiguration
        _feedProcessPostRulesChanged(author, postId, rules, feedRulesData);
    }

    function updatePostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData,
        RuleExecutionData calldata changeRulesQuotePostRulesData,
        RuleExecutionData calldata changeRulesParentPostRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(!Core.$storage().posts[postId].isRepost, "CANNOT_UPDATE_RULES_ON_REPOST");
        for (uint256 i = 0; i < rules.length; i++) {
            _updatePostRule(postId, rules[i]);
            emit Lens_Feed_Post_RuleUpdated(
                postId, author, rules[i].ruleAddress, rules[i].configData, rules[i].isRequired
            );
        }
        _processAllParentsRulesChildPostRulesChanged(
            postId, rules, changeRulesQuotePostRulesData, changeRulesParentPostRulesData
        );

        // Check the feed rules if it accepts the new RuleConfiguration
        _feedProcessPostRulesChanged(author, postId, rules, feedRulesData);
    }

    function removePostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData,
        RuleExecutionData calldata changeRulesQuotePostRulesData,
        RuleExecutionData calldata changeRulesParentPostRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(!Core.$storage().posts[postId].isRepost, "CANNOT_REMOVE_RULES_FROM_REPOST");
        for (uint256 i = 0; i < rules.length; i++) {
            _removePostRule(postId, rules[i].ruleAddress);
            emit Lens_Feed_Post_RuleRemoved(postId, author, rules[i].ruleAddress);
        }
        _processAllParentsRulesChildPostRulesChanged(
            postId, rules, changeRulesQuotePostRulesData, changeRulesParentPostRulesData
        );

        // Check the feed rules if it accepts the new RuleConfiguration
        _feedProcessPostRulesChanged(author, postId, rules, feedRulesData);
    }

    // Public user functions

    function createPost(CreatePostParams calldata createPostParams) external override returns (uint256) {
        require(msg.sender == createPostParams.author, "MSG_SENDER_NOT_AUTHOR");
        if (createPostParams.parentPostId != 0) {
            require(createPostParams.quotedPostId != createPostParams.parentPostId, "CANNOT_BE_QUOTED_AND_PARENT");
        }
        require(!Core.$storage().posts[createPostParams.parentPostId].isRepost, "REPOST_CANNOT_BE_PARENT");
        require(!Core.$storage().posts[createPostParams.quotedPostId].isRepost, "REPOST_CANNOT_BE_QUOTED");
        (uint256 postId, uint256 localSequentialId, uint256 rootPostId) = Core._createPost(createPostParams);
        _feedProcessCreatePost(postId, localSequentialId, createPostParams);

        // We can only add rules to the post on creation, or by calling dedicated functions after (not on editPost)
        for (uint256 i = 0; i < createPostParams.rules.length; i++) {
            _addPostRule(postId, createPostParams.rules[i]);
            emit Lens_Feed_RuleAdded(
                createPostParams.rules[i].ruleAddress,
                createPostParams.rules[i].configData,
                createPostParams.rules[i].isRequired
            );
        }
        _processAllParentsRulesChildPostRulesChanged(
            postId,
            createPostParams.rules,
            createPostParams.changeRulesQuotePostRulesData,
            createPostParams.changeRulesParentPostRulesData
        );

        // Check the feed rules if it accepts the new RuleConfiguration
        _feedProcessPostRulesChanged(
            createPostParams.author, postId, createPostParams.rules, createPostParams.feedRulesData
        );

        _processAllParentsAndQuotedPostsRules(
            createPostParams.quotedPostId,
            createPostParams.parentPostId,
            postId,
            createPostParams.quotesPostRulesData,
            createPostParams.parentsPostRulesData
        );

        emit Lens_Feed_PostCreated(postId, createPostParams.author, localSequentialId, createPostParams, rootPostId);
        return postId;
    }

    function createRepost(CreateRepostParams calldata createRepostParams) external override returns (uint256) {
        require(msg.sender == createRepostParams.author, "MSG_SENDER_NOT_AUTHOR");
        require(!Core.$storage().posts[createRepostParams.parentPostId].isRepost, "CANNOT_REPOST_REPOST");
        (uint256 postId, uint256 localSequentialId, uint256 rootPostId) = Core._createRepost(createRepostParams);
        _feedProcessCreateRepost(postId, localSequentialId, createRepostParams);

        _processAllParentsPostsRules(createRepostParams.parentPostId, postId, createRepostParams.parentsPostRulesData);

        emit Lens_Feed_RepostCreated(
            postId, createRepostParams.author, localSequentialId, createRepostParams, rootPostId
        );
        return postId;
    }

    function editPost(
        uint256 postId,
        EditPostParams calldata newPostParams,
        RuleExecutionData calldata editPostFeedRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        // TODO: We can have this for moderators:
        // require(msg.sender == author || _hasAccess(msg.sender, EDIT_POST_RID));
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        _feedProcessEditPost(postId, newPostParams, editPostFeedRulesData);
        Core._editPost(postId, newPostParams);
        emit Lens_Feed_PostEdited(postId, author, newPostParams, editPostFeedRulesData);
    }

    function deletePost(
        uint256 postId,
        bytes32[] calldata extraDataKeysToDelete,
        RuleExecutionData calldata feedRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author || _hasAccess(msg.sender, DELETE_POST_RID), "MSG_SENDER_NOT_AUTHOR_NOR_HAS_ACCESS");
        _feedProcessDeletePost(postId, feedRulesData);
        Core._deletePost(postId, extraDataKeysToDelete);
        emit Lens_Feed_PostDeleted(postId, author, feedRulesData);
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        // Core.$storage().accessControl.requireAccess(msg.sender, SET_EXTRA_DATA_RID);
        Core._setExtraData(extraDataToSet);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            emit Lens_Feed_ExtraDataSet(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
        }
    }

    // Getters

    function getPost(uint256 postId) external view override returns (Post memory) {
        return Post({
            author: Core.$storage().posts[postId].author,
            localSequentialId: Core.$storage().posts[postId].localSequentialId,
            source: Core.$storage().posts[postId].source,
            contentURI: Core.$storage().posts[postId].contentURI,
            isRepost: Core.$storage().posts[postId].isRepost,
            quotedPostId: Core.$storage().posts[postId].quotedPostId,
            parentPostId: Core.$storage().posts[postId].parentPostId,
            requiredRules: _getPostRules(postId, true),
            anyOfRules: _getPostRules(postId, false),
            creationTimestamp: Core.$storage().posts[postId].creationTimestamp,
            lastUpdatedTimestamp: Core.$storage().posts[postId].lastUpdatedTimestamp
        });
    }

    function getPostAuthor(uint256 postId) external view override returns (address) {
        return Core.$storage().posts[postId].author;
    }

    function getFeedRules(bool isRequired) external view override returns (address[] memory) {
        return _getFeedRules(isRequired);
    }

    function getPostRules(uint256 postId, bool isRequired) external view override returns (address[] memory) {
        return _getPostRules(postId, isRequired);
    }

    function getPostCount() external view override returns (uint256) {
        return Core.$storage().postCount;
    }

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }

    function getPostExtraData(uint256 postId, bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().posts[postId].extraData[key];
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().extraData[key];
    }
}
