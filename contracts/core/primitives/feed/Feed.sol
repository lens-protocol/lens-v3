// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFeed, Post, EditPostParams, CreatePostParams} from "./../../interfaces/IFeed.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {IAccessControl} from "./../../interfaces/IAccessControl.sol";
import {KeyValue} from "./../../types/Types.sol";
import {RuleBasedFeed} from "./RuleBasedFeed.sol";
import {AccessControlled} from "./../../access/AccessControlled.sol";
import {RuleConfiguration, RuleChange, RuleOperation, RuleExecutionData, SourceStamp} from "./../../types/Types.sol";
import {Events} from "./../../types/Events.sol";
import {ISource} from "./../../interfaces/ISource.sol";

contract Feed is IFeed, RuleBasedFeed, AccessControlled {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_PID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_PID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_PID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant DELETE_POST_PID = uint256(keccak256("DELETE_POST"));

    constructor(string memory metadataURI, IAccessControl accessControl) AccessControlled(accessControl) {
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Feed_MetadataURISet(metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed("feed", "lens.feed", "feed", "lens.feed");
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(SET_RULES_PID, "SET_RULES");
        emit Events.Lens_PermissionId_Available(SET_METADATA_PID, "SET_METADATA");
        emit Events.Lens_PermissionId_Available(SET_EXTRA_DATA_PID, "SET_EXTRA_DATA");
        emit Events.Lens_PermissionId_Available(DELETE_POST_PID, "DELETE_POST");
    }

    // Access Controlled functions

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Feed_MetadataURISet(metadataURI);
    }

    function changeFeedRules(RuleChange[] calldata ruleChanges) external override {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfiguration memory ruleConfig = ruleChanges[i].configuration;
            if (ruleChanges[i].operation == RuleOperation.ADD) {
                _addFeedRule(ruleConfig);
                emit Lens_Feed_RuleAdded(ruleConfig.ruleAddress, ruleConfig.configData, ruleConfig.isRequired);
            } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                _updateFeedRule(ruleConfig);
                emit Lens_Feed_RuleUpdated(ruleConfig.ruleAddress, ruleConfig.configData, ruleConfig.isRequired);
            } else {
                _removeFeedRule(ruleConfig.ruleAddress);
                emit Lens_Feed_RuleRemoved(ruleConfig.ruleAddress);
            }
        }
    }

    // PostRules functions

    function changePostRules(
        uint256 postId,
        RuleChange[] calldata ruleChanges,
        RuleExecutionData calldata feedRulesData
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        require(Core.$storage().posts[postId].rootPostId == postId, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
        for (uint256 i = 0; i < ruleChanges.length; i++) {
            RuleConfiguration memory ruleConfig = ruleChanges[i].configuration;
            if (ruleChanges[i].operation == RuleOperation.ADD) {
                _addPostRule(postId, ruleConfig);
                emit Lens_Feed_Post_RuleAdded(
                    postId, author, ruleConfig.ruleAddress, ruleConfig.configData, ruleConfig.isRequired
                );
            } else if (ruleChanges[i].operation == RuleOperation.UPDATE) {
                _updatePostRule(postId, ruleConfig);
                emit Lens_Feed_Post_RuleUpdated(
                    postId, author, ruleConfig.ruleAddress, ruleConfig.configData, ruleConfig.isRequired
                );
            } else {
                _removePostRule(postId, ruleConfig.ruleAddress);
                emit Lens_Feed_Post_RuleRemoved(postId, author, ruleConfig.ruleAddress);
            }
        }
        // Check the feed rules if it accepts the new RuleConfiguration
        _processChangesOnPostRules(postId, ruleChanges, feedRulesData);
    }

    // Public user functions

    function createPost(
        CreatePostParams calldata createPostParams,
        SourceStamp calldata sourceStamp
    ) external override returns (uint256) {
        require(msg.sender == createPostParams.author, "MSG_SENDER_NOT_AUTHOR");

        (uint256 postId, uint256 localSequentialId, uint256 rootPostId) =
            Core._createPost(createPostParams, sourceStamp.source);
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        _processPostCreation(postId, createPostParams);

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
            RuleChange[] memory ruleChanges = new RuleChange[](createPostParams.rules.length);
            // We can only add rules to the post on creation, or by calling dedicated functions after (not on editPost)
            for (uint256 i = 0; i < createPostParams.rules.length; i++) {
                _addPostRule(postId, createPostParams.rules[i]);
                emit Lens_Feed_RuleAdded(
                    createPostParams.rules[i].ruleAddress,
                    createPostParams.rules[i].configData,
                    createPostParams.rules[i].isRequired
                );
                ruleChanges[i] = RuleChange({operation: RuleOperation.ADD, configuration: createPostParams.rules[i]});
            }

            // Check if Feed rules allows the given Post's rule configuration
            _processChangesOnPostRules(postId, ruleChanges, createPostParams.feedRulesData);
        }

        emit Lens_Feed_PostCreated(
            postId, createPostParams.author, localSequentialId, createPostParams, rootPostId, sourceStamp.source
        );

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
        RuleExecutionData calldata editPostFeedRulesData,
        SourceStamp calldata sourceStamp
    ) external override {
        address author = Core.$storage().posts[postId].author;
        // TODO: We can have this for moderators:
        // require(msg.sender == author || _hasAccess(msg.sender, EDIT_POST_PID));
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");
        _feedProcessEditPost(postId, newPostParams, editPostFeedRulesData);
        bool[] memory wereExtraDataValuesSet = Core._editPost(postId, newPostParams, sourceStamp.source);
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        emit Lens_Feed_PostEdited(postId, author, newPostParams, editPostFeedRulesData, sourceStamp.source);
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
        RuleExecutionData calldata feedRulesData,
        SourceStamp calldata sourceStamp
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author || _hasAccess(msg.sender, DELETE_POST_PID), "MSG_SENDER_NOT_AUTHOR_NOR_HAS_ACCESS");
        Core._deletePost(postId, extraDataKeysToDelete);
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        emit Lens_Feed_PostDeleted(postId, author, feedRulesData, sourceStamp.source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = Core._setExtraData(extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    emit Lens_Feed_ExtraDataRemoved(extraDataToSet[i].key);
                } else {
                    emit Lens_Feed_ExtraDataUpdated(
                        extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                    );
                }
            } else if (!isNewValueEmpty) {
                emit Lens_Feed_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            }
        }
    }

    // Getters

    function getPost(uint256 postId) external view override returns (Post memory) {
        // TODO: Should fail if post doesn't exist
        return Post({
            author: Core.$storage().posts[postId].author,
            localSequentialId: Core.$storage().posts[postId].localSequentialId,
            contentURI: Core.$storage().posts[postId].contentURI,
            rootPostId: Core.$storage().posts[postId].rootPostId,
            repostedPostId: Core.$storage().posts[postId].repostedPostId,
            quotedPostId: Core.$storage().posts[postId].quotedPostId,
            repliedPostId: Core.$storage().posts[postId].repliedPostId,
            requiredRules: _getPostRules(postId, true),
            anyOfRules: _getPostRules(postId, false),
            creationTimestamp: Core.$storage().posts[postId].creationTimestamp,
            creationSource: Core.$storage().posts[postId].creationSource,
            lastUpdatedTimestamp: Core.$storage().posts[postId].lastUpdatedTimestamp,
            lastUpdateSource: Core.$storage().posts[postId].lastUpdateSource
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
