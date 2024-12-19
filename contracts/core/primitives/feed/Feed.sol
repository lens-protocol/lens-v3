// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFeed, Post, EditPostParams, CreatePostParams} from "./../../interfaces/IFeed.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {IAccessControl} from "./../../interfaces/IAccessControl.sol";
import {RuleBasedFeed} from "./RuleBasedFeed.sol";
import {AccessControlled} from "./../../access/AccessControlled.sol";
import {ExtraStorageBased} from "./../../base/ExtraStorageBased.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "./../../types/Types.sol";
import {Events} from "./../../types/Events.sol";
import {SourceStampBased} from "./../../base/SourceStampBased.sol";

contract Feed is IFeed, RuleBasedFeed, AccessControlled, ExtraStorageBased, SourceStampBased {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_PID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_PID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_PID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant REMOVE_POST_PID = uint256(keccak256("REMOVE_POST"));

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
        emit Events.Lens_PermissionId_Available(REMOVE_POST_PID, "REMOVE_POST");
    }

    // Access Controlled functions

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Feed_MetadataURISet(metadataURI);
    }

    function _beforeChangePrimitiveRules(RuleChange[] calldata /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, SET_RULES_PID);
    }

    function _beforeChangeEntityRules(
        uint256 entityId,
        RuleChange[] calldata /* ruleChanges */
    ) internal virtual override {
        // TODO: What should we validate here?
    }

    // Public user functions

    function createPost(
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams,
        RuleProcessingParams[] calldata rootPostRulesParams,
        RuleProcessingParams[] calldata quotedPostRulesParams
    ) external override returns (uint256) {
        require(msg.sender == postParams.author, "MSG_SENDER_NOT_AUTHOR");
        (uint256 postId, uint256 localSequentialId, uint256 rootPostId) = Core._createPost(postParams);
        address source = _processSourceStamp(postId, customParams);
        _setPrimitiveInternalExtraDataForEntity(postId, KeyValue(LAST_UPDATED_SOURCE_EXTRA_DATA, abi.encode(source)));
        _processPostCreationOnFeed(postId, postParams, customParams, feedRulesParams);
        // Process rules of the Quote (if quoting)
        if (postParams.quotedPostId != 0) {
            // TODO: Maybe quotes shouldn't be limited by rules... Just a brave thought. Like quotations in real life.
            uint256 rootOfQuotedPost = Core.$storage().posts[postParams.quotedPostId].rootPostId;
            if (rootOfQuotedPost != rootPostId) {
                _processPostCreationOnRootPost(rootOfQuotedPost, postId, postParams, customParams, quotedPostRulesParams);
            }
        }
        if (postId != rootPostId) {
            require(postParams.ruleChanges.length == 0, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
            // This covers the Reply or Repost cases
            _processPostCreationOnRootPost(rootPostId, postId, postParams, customParams, rootPostRulesParams);
        } else {
            _addPostRulesAtCreation(postId, postParams, feedRulesParams);
        }
        emit Lens_Feed_PostCreated(
            postId,
            postParams.author,
            localSequentialId,
            rootPostId,
            postParams,
            customParams,
            feedRulesParams,
            rootPostRulesParams,
            quotedPostRulesParams,
            source
        );
        for (uint256 i = 0; i < postParams.extraData.length; i++) {
            _setEntityExtraData(postId, postParams.extraData[i]);
            emit Lens_Feed_Post_ExtraDataAdded(
                postId, postParams.extraData[i].key, postParams.extraData[i].value, postParams.extraData[i].value
            );
        }
        return postId;
    }

    function editPost(
        uint256 postId,
        EditPostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams,
        RuleProcessingParams[] calldata rootPostRulesParams,
        RuleProcessingParams[] calldata quotedPostRulesParams
    ) external override {
        address author = Core.$storage().posts[postId].author;
        // TODO: We can have this for moderators:
        // require(msg.sender == author || _hasAccess(msg.sender, EDIT_POST_PID));
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");

        bool[] memory wereExtraDataValuesSet = new bool[](postParams.extraData.length);
        for (uint256 i = 0; i < postParams.extraData.length; i++) {
            wereExtraDataValuesSet[i] = _setEntityExtraData(postId, postParams.extraData[i]);
        }

        _processPostEditingOnFeed(postId, postParams, customParams, rootPostRulesParams);
        uint256 quotedPostId = Core.$storage().posts[postId].quotedPostId;
        if (quotedPostId != 0) {
            uint256 rootOfQuotedPost = Core.$storage().posts[quotedPostId].rootPostId;
            _processPostEditingOnRootPost(rootOfQuotedPost, postId, postParams, customParams, quotedPostRulesParams);
        }
        uint256 rootPostId = Core.$storage().posts[postId].rootPostId;
        if (postId != rootPostId) {
            _processPostEditingOnRootPost(rootPostId, postId, postParams, customParams, rootPostRulesParams);
        }
        address source = _processSourceStamp({
            entityId: postId,
            customParams: customParams,
            storeSource: true,
            lastUpdatedSourceType: true
        });
        emit Lens_Feed_PostEdited(
            postId, author, postParams, customParams, feedRulesParams, rootPostRulesParams, quotedPostRulesParams, source
        );
        for (uint256 i = 0; i < postParams.extraData.length; i++) {
            if (wereExtraDataValuesSet[i]) {
                emit Lens_Feed_Post_ExtraDataUpdated(
                    postId, postParams.extraData[i].key, postParams.extraData[i].value, postParams.extraData[i].value
                );
            } else {
                emit Lens_Feed_Post_ExtraDataAdded(
                    postId, postParams.extraData[i].key, postParams.extraData[i].value, postParams.extraData[i].value
                );
            }
        }
    }

    // TODO: Decide how DELETE operation should work in Feed (soft vs. hard delete)
    function removePost(
        uint256 postId,
        bytes32[] calldata, /*extraDataKeysToRemove*/ // TODO: Consider moving this into customParams
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author || _hasAccess(msg.sender, REMOVE_POST_PID), "MSG_SENDER_NOT_AUTHOR_NOR_HAS_ACCESS");
        Core._removePost(postId);
        _processPostRemoval(postId, customParams, feedRulesParams);
        address source = _processSourceStamp(postId, customParams);
        emit Lens_Feed_PostRemoved(postId, author, customParams, source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setPrimitiveExtraData(extraDataToSet[i]);
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
            authorPostSequentialId: Core.$storage().posts[postId].authorPostSequentialId,
            postSequentialId: Core.$storage().posts[postId].postSequentialId,
            contentURI: Core.$storage().posts[postId].contentURI,
            rootPostId: Core.$storage().posts[postId].rootPostId,
            repostedPostId: Core.$storage().posts[postId].repostedPostId,
            quotedPostId: Core.$storage().posts[postId].quotedPostId,
            repliedPostId: Core.$storage().posts[postId].repliedPostId,
            creationTimestamp: Core.$storage().posts[postId].creationTimestamp,
            creationSource: _getSource(postId),
            lastUpdatedTimestamp: Core.$storage().posts[postId].lastUpdatedTimestamp,
            lastUpdateSource: _getLastUpdateSource(postId)
        });
    }

    function getPostAuthor(uint256 postId) external view override returns (address) {
        // TODO: Should fail if post doesn't exist?
        return Core.$storage().posts[postId].author;
    }

    function getPostCount() external view override returns (uint256) {
        return Core.$storage().postCount;
    }

    function getPostCount(address author) external view override returns (uint256) {
        return Core.$storage().authorPostCount[author];
    }

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }

    function getPostExtraData(uint256 postId, bytes32 key) external view override returns (bytes memory) {
        address postAuthor = Core.$storage().posts[postId].author;
        return _getEntityExtraData(postAuthor, postId, key);
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getPrimitiveExtraData(key);
    }

    function getPostSequentialId(uint256 postId) external view override returns (uint256) {
        return Core.$storage().posts[postId].postSequentialId;
    }

    function getAuthorPostSequentialId(uint256 postId) external view override returns (uint256) {
        return Core.$storage().posts[postId].authorPostSequentialId;
    }

    function getNextPostId(address author) external view returns (uint256) {
        return Core._generatePostId(author, Core.$storage().authorPostCount[author] + 1);
    }
}
