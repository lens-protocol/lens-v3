// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IFeed, Post, EditPostParams, CreatePostParams} from "./../../interfaces/IFeed.sol";
import {FeedCore as Core} from "./FeedCore.sol";
import {IAccessControl} from "./../../interfaces/IAccessControl.sol";
import {KeyValue} from "./../../types/Types.sol";
import {RuleBasedFeed} from "./RuleBasedFeed.sol";
import {AccessControlled} from "./../../access/AccessControlled.sol";
import {ExtraStorageBased} from "./../../base/ExtraStorageBased.sol";
import {
    RuleConfigurationParams,
    RuleChange,
    RuleOperation,
    RuleProcessingParams,
    SourceStamp
} from "./../../types/Types.sol";
import {Events} from "./../../types/Events.sol";
import {ISource} from "./../../interfaces/ISource.sol";

contract Feed is IFeed, RuleBasedFeed, AccessControlled, ExtraStorageBased {
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

    function _beforeChangeFeedRules(RuleChange[] calldata /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, SET_RULES_PID);
    }

    // Public user functions

    function createPost(
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams,
        RuleProcessingParams[] calldata postRulesParams,
        SourceStamp calldata sourceStamp
    ) external override returns (uint256) {
        require(msg.sender == postParams.author, "MSG_SENDER_NOT_AUTHOR");
        (uint256 postId, uint256 localSequentialId, uint256 rootPostId) =
            Core._createPost(postParams, sourceStamp.source);
        _processSourceStamp(sourceStamp);
        _processPostCreationOnFeed(postId, postParams, customParams, feedRulesParams);
        if (postId != rootPostId) {
            require(postParams.rules.length == 0, "ONLY_ROOT_POSTS_CAN_HAVE_RULES");
            // TODO: We might need to call this on the root post of the quoted, replied, and/or reposted posts...
            // Check how it was done before... we get the root from each of them, and process the rules on them
            _processPostCreationOnRootPost(rootPostId, postId, postParams, customParams, postRulesParams);
        } else {
            RuleChange[] memory ruleChanges = new RuleChange[](postParams.rules.length);
            // We can only add rules to the post on creation, or by calling dedicated functions after (not on editPost)
            for (uint256 i = 0; i < postParams.rules.length; i++) {
                _addPostRule(postId, postParams.rules[i]);
                emit Lens_Feed_RuleAdded(
                    postParams.rules[i].ruleAddress,
                    postParams.rules[i].configSalt,
                    postParams.rules[i].ruleSelector,
                    postParams.rules[i].customParams,
                    postParams.rules[i].isRequired
                );
                ruleChanges[i] = RuleChange({operation: RuleOperation.ADD, configuration: postParams.rules[i]});
            }
            // Check if Feed rules allows the given Post's rule configuration
            _processPostRulesChanges(postId, ruleChanges, feedRulesParams);
        }
        emit Lens_Feed_PostCreated(
            postId,
            postParams.author,
            localSequentialId,
            rootPostId,
            postParams,
            feedRulesParams,
            postRulesParams,
            sourceStamp.source
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
        RuleProcessingParams[] calldata postRulesParams,
        SourceStamp calldata sourceStamp
    ) external override {
        address author = Core.$storage().posts[postId].author;
        // TODO: We can have this for moderators:
        // require(msg.sender == author || _hasAccess(msg.sender, EDIT_POST_PID));
        require(msg.sender == author, "MSG_SENDER_NOT_AUTHOR");

        bool[] memory wereExtraDataValuesSet = new bool[](postParams.extraData.length);
        for (uint256 i = 0; i < postParams.extraData.length; i++) {
            wereExtraDataValuesSet[i] = _setEntityExtraData(postId, postParams.extraData[i]);
        }

        _processPostEditingOnFeed(postId, postParams, customParams, postRulesParams);
        uint256 rootPostId = Core.$storage().posts[postId].rootPostId;
        if (postId != rootPostId) {
            _processPostEditingOnRootPost(rootPostId, postId, postParams, customParams, postRulesParams);
        }
        _processSourceStamp(sourceStamp);
        emit Lens_Feed_PostEdited(postId, author, postParams, feedRulesParams, postRulesParams, sourceStamp.source);
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

    function deletePost(
        uint256 postId,
        bytes32[] calldata, /*extraDataKeysToDelete*/ // TODO: Consider moving this into customParams
        KeyValue[] calldata customParams,
        SourceStamp calldata sourceStamp
    ) external override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author || _hasAccess(msg.sender, DELETE_POST_PID), "MSG_SENDER_NOT_AUTHOR_NOR_HAS_ACCESS");
        Core._deletePost(postId);
        _processSourceStamp(sourceStamp);
        emit Lens_Feed_PostDeleted(postId, author, customParams, sourceStamp.source);
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

    function _processSourceStamp(SourceStamp calldata sourceStamp) internal {
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
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

    function getPostCount() external view override returns (uint256) {
        return Core.$storage().postCount;
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
}
