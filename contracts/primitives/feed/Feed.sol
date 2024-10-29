// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFeed, Post, EditPostParams, CreatePostParams} from "./IFeed.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {DataElement} from "./../../types/Types.sol";
import {RuleBasedFeed} from "./RuleBasedFeed.sol";
import {AccessControlled} from "./../base/AccessControlled.sol";
import {RuleConfiguration, RuleExecutionData, DataElementValue} from "./../../types/Types.sol";
import {Events} from "./../../types/Events.sol";

contract Feed is IFeed, RuleBasedFeed, AccessControlled {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_PID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_PID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_PID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant DELETE_POST_PID = uint256(keccak256("DELETE_POST"));

    constructor(address metadataURISource, string memory metadataURI, IAccessControl accessControl)
        AccessControlled(accessControl)
    {
        Core.$storage().metadataURI[metadataURISource] = metadataURI;
        emit Lens_Feed_MetadataURISet(metadataURISource, metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed("feed", "lens.feed", "feed", "lens.feed");
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Lens_PermissonId_Available(SET_RULES_PID, "SET_RULES");
        emit Lens_PermissonId_Available(SET_METADATA_PID, "SET_METADATA");
        emit Lens_PermissonId_Available(SET_EXTRA_DATA_PID, "SET_EXTRA_DATA");
        emit Lens_PermissonId_Available(DELETE_POST_PID, "DELETE_POST");
    }

    // Access Controlled functions

    function setMetadataURI(address source, string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        Core.$storage().metadataURI[source] = metadataURI;
        emit Lens_Feed_MetadataURISet(source, metadataURI);
    }

    function addFeedRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < rules.length; i++) {
            _addFeedRule(rules[i]);
            emit Lens_Feed_RuleAdded(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function updateFeedRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < rules.length; i++) {
            _updateFeedRule(rules[i]);
            emit Lens_Feed_RuleUpdated(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function removeFeedRules(address[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeFeedRule(rules[i]);
            emit Lens_Feed_RuleRemoved(rules[i]);
        }
    }

    // PostRules functions // TODO: Move these in a proper place later

    function addPostRules(uint256 postId, RuleConfiguration[] calldata rules, RuleExecutionData calldata feedRulesData)
        external
        override
    {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(Core.$storage().posts[postId].rootPostId == postId, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
        for (uint256 i = 0; i < rules.length; i++) {
            _addPostRule(postId, rules[i]);
            emit Lens_Feed_Post_RuleAdded(
                postId, author, rules[i].ruleAddress, rules[i].configData, rules[i].isRequired
            );
        }

        uint256 localSequentialId = Core.$storage().posts[postId].localSequentialId;
        // Check the feed rules if it accepts the new RuleConfiguration
        _processChangesOnPostRules(postId, localSequentialId, rules, feedRulesData);
    }

    function updatePostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(Core.$storage().posts[postId].rootPostId == postId, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
        for (uint256 i = 0; i < rules.length; i++) {
            _updatePostRule(postId, rules[i]);
            emit Lens_Feed_Post_RuleUpdated(
                postId, author, rules[i].ruleAddress, rules[i].configData, rules[i].isRequired
            );
        }

        uint256 localSequentialId = Core.$storage().posts[postId].localSequentialId;
        // Check the feed rules if it accepts the new RuleConfiguration
        _processChangesOnPostRules(postId, localSequentialId, rules, feedRulesData);
    }

    function removePostRules(
        uint256 postId,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata feedRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(Core.$storage().posts[postId].rootPostId == postId, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
        for (uint256 i = 0; i < rules.length; i++) {
            _removePostRule(postId, rules[i].ruleAddress);
            emit Lens_Feed_Post_RuleRemoved(postId, author, rules[i].ruleAddress);
        }

        uint256 localSequentialId = Core.$storage().posts[postId].localSequentialId;
        // Check the feed rules if it accepts the new RuleConfiguration
        _processChangesOnPostRules(postId, localSequentialId, rules, feedRulesData);
    }

    // Public user functions

    function createPost(CreatePostParams calldata createPostParams) external override returns (uint256) {
        require(msg.sender == createPostParams.author, "MSG_SENDER_NOT_AUTHOR");

        (uint256 postId, uint256 localSequentialId, uint256 rootPostId) = Core._createPost(createPostParams);
        _processPostCreation(postId, localSequentialId, createPostParams);

        if (createPostParams.quotedPostId != 0) {
            _processQuotedPostRules(createPostParams.quotedPostId, postId, createPostParams.quotedPostRulesData);
        }

        if (createPostParams.repliedPostId != 0) {
            _processRepliedPostRules(createPostParams.repliedPostId, postId, createPostParams.repliedPostRulesData);
        }

        if (createPostParams.repostedPostId != 0) {
            _processRepostedPostRules(createPostParams.repliedPostId, postId, createPostParams.repostedPostRulesData);
        }

        if (postId != rootPostId) {
            require(createPostParams.rules.length == 0, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
        } else {
            // We can only add rules to the post on creation, or by calling dedicated functions after (not on editPost)
            for (uint256 i = 0; i < createPostParams.rules.length; i++) {
                _addPostRule(postId, createPostParams.rules[i]);
                emit Lens_Feed_RuleAdded(
                    createPostParams.rules[i].ruleAddress,
                    createPostParams.rules[i].configData,
                    createPostParams.rules[i].isRequired
                );
            }

            // Check if Feed rules allows the given Post's rule configuration
            _processChangesOnPostRules(
                postId, localSequentialId, createPostParams.rules, createPostParams.feedRulesData
            );
        }

        emit Lens_Feed_PostCreated(postId, createPostParams.author, localSequentialId, createPostParams, rootPostId);

        for (uint256 i = 0; i < createPostParams.extraData.length; i++) {
            emit Lens_Feed_Post_ExtraDataAdded(
                postId,
                createPostParams.extraData[i].key,
                createPostParams.extraData[i].value,
                createPostParams.extraData[i].value
            );
        }

        return postId;
    }

    function editPost(
        uint256 postId,
        EditPostParams calldata newPostParams,
        RuleExecutionData calldata editPostFeedRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        // TODO: We can have this for moderators:
        // require(msg.sender == author || _hasAccess(msg.sender, EDIT_POST_PID));
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        uint256 localSequentialId = Core.$storage().posts[postId].localSequentialId;
        _feedProcessEditPost(postId, localSequentialId, newPostParams, editPostFeedRulesData);
        bool[] memory wereExtraDataValuesSet = Core._editPost(postId, newPostParams);
        emit Lens_Feed_PostEdited(postId, author, newPostParams, editPostFeedRulesData);
        for (uint256 i = 0; i < newPostParams.extraData.length; i++) {
            if (wereExtraDataValuesSet[i]) {
                emit Lens_Feed_Post_ExtraDataUpdated(
                    postId,
                    newPostParams.extraData[i].key,
                    newPostParams.extraData[i].value,
                    newPostParams.extraData[i].value
                );
            } else {
                emit Lens_Feed_Post_ExtraDataAdded(
                    postId,
                    newPostParams.extraData[i].key,
                    newPostParams.extraData[i].value,
                    newPostParams.extraData[i].value
                );
            }
        }
    }

    function deletePost(
        uint256 postId,
        bytes32[] calldata extraDataKeysToDelete,
        RuleExecutionData calldata feedRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author || _hasAccess(msg.sender, DELETE_POST_PID), "MSG_SENDER_NOT_AUTHOR_NOR_HAS_ACCESS");
        uint256 localSequentialId = Core.$storage().posts[postId].localSequentialId;
        _feedProcessDeletePost(postId, localSequentialId, feedRulesData);
        Core._deletePost(postId, extraDataKeysToDelete);
        emit Lens_Feed_PostDeleted(postId, author, feedRulesData);
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool wasExtraDataAlreadySet = Core._setExtraData(extraDataToSet[i]);
            if (wasExtraDataAlreadySet) {
                emit Lens_Feed_ExtraDataUpdated(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            } else {
                emit Lens_Feed_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            }
        }
    }

    function removeExtraData(bytes32[] calldata extraDataKeysToRemove) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataKeysToRemove.length; i++) {
            Core._removeExtraData(extraDataKeysToRemove[i]);
            emit Lens_Feed_ExtraDataRemoved(extraDataKeysToRemove[i]);
        }
    }

    // Getters

    function getPost(uint256 postId) external view override returns (Post memory) {
        // TODO: Should fail if post doesn't exist
        return Post({
            author: Core.$storage().posts[postId].author,
            localSequentialId: Core.$storage().posts[postId].localSequentialId,
            source: Core.$storage().posts[postId].source,
            contentURI: Core.$storage().posts[postId].contentURI,
            repostedPostId: Core.$storage().posts[postId].repostedPostId,
            quotedPostId: Core.$storage().posts[postId].quotedPostId,
            repliedPostId: Core.$storage().posts[postId].repliedPostId,
            requiredRules: _getPostRules(postId, true),
            anyOfRules: _getPostRules(postId, false),
            creationTimestamp: Core.$storage().posts[postId].creationTimestamp,
            lastUpdatedTimestamp: Core.$storage().posts[postId].lastUpdatedTimestamp
        });
    }

    function getPostAuthor(uint256 postId) external view override returns (address) {
        // TODO: Should fail if post doesn't exist
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

    function getMetadataURI(address source) external view override returns (string memory) {
        return Core.$storage().metadataURI[source];
    }

    function getPostExtraData(uint256 postId, bytes32 key) external view override returns (DataElementValue memory) {
        return Core.$storage().posts[postId].extraData[key];
    }

    function getExtraData(bytes32 key) external view override returns (DataElementValue memory) {
        return Core.$storage().extraData[key];
    }
}
