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
import {MetadataBased} from "./../../base/MetadataBased.sol";
import {AccessControlLib} from "./../../libraries/AccessControlLib.sol";

contract Feed is IFeed, RuleBasedFeed, AccessControlled, ExtraStorageBased, SourceStampBased, MetadataBased {
    using AccessControlLib for IAccessControl;
    // TODO: Move these to respective contracts
    // Resource IDs involved in the contract

    /// @custom:keccak lens.permission.SetMetadata
    uint256 constant PID__SET_METADATA = uint256(0xe40fdb273cda3c78f0d9b6d20f5378755989e26c60c89696e5eea644d84eefea);
    /// @custom:keccak lens.permission.ChangeRules
    uint256 constant PID__CHANGE_RULES = uint256(0x550b12ef6572134aefc5804fd2b13ab3d8451e067ad453f67afe134cffebd977);
    /// @custom:keccak lens.permission.SetExtraData
    uint256 constant PID__SET_EXTRA_DATA = uint256(0x9b4afa2e6d7162f878076bb1210736928cd607a384b985eca0dba5e94790e72a);
    /// @custom:keccak lens.permission.RemovePost
    uint256 constant PID__REMOVE_POST = uint256(0x25b86c749bcf827bec85b3f107e1d65771462eb329e68ff158d50a2f4b301c89);

    constructor(string memory, /* metadataURI */ IAccessControl accessControl) AccessControlled(accessControl) {}

    function initialize(string memory metadataURI, IAccessControl accessControl) external {
        // TODO: Replace with inheriting the Initializable contract

        require(bytes(_getMetadataURI()).length == 0, "ALREADY_INITIALIZED");
        _setMetadataURI(metadataURI);
        _emitPIDs();
        accessControl.verifyHasAccessFunction();
        _setAccessControl(accessControl);
        emit Events.Lens_Contract_Deployed("feed", "lens.feed", "feed", "lens.feed");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Feed_MetadataURISet(metadataURI);
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(PID__CHANGE_RULES, "lens.permission.ChangeRules");
        emit Events.Lens_PermissionId_Available(PID__SET_METADATA, "lens.permission.SetMetadata");
        emit Events.Lens_PermissionId_Available(PID__SET_EXTRA_DATA, "lens.permission.SetExtraData");
        emit Events.Lens_PermissionId_Available(PID__REMOVE_POST, "lens.permission.RemovePost");
    }

    // Access Controlled functions

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal view override {
        _requireAccess(msg.sender, PID__SET_METADATA);
    }

    function _beforeChangePrimitiveRules(RuleChange[] calldata /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, PID__CHANGE_RULES);
    }

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] calldata /* ruleChanges */ )
        internal
        virtual
        override
    {
        require(msg.sender == Core.$storage().posts[entityId].author);
    }

    // Public user functions

    function createPost(
        CreatePostParams calldata postParams,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams,
        RuleProcessingParams[] calldata rootPostRulesParams,
        RuleProcessingParams[] calldata quotedPostRulesParams
    ) external virtual override returns (uint256) {
        require(msg.sender == postParams.author, "MSG_SENDER_NOT_AUTHOR");
        (uint256 postId, uint256 authorPostSequentialId, uint256 rootPostId) = Core._createPost(postParams);
        address source = _processSourceStamp(postId, customParams);
        _setPrimitiveInternalExtraDataForEntity(postId, KeyValue(DATA__LAST_UPDATED_SOURCE, abi.encode(source)));
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
            authorPostSequentialId,
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
    ) external virtual override {
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

    function deletePost(
        uint256 postId,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata feedRulesParams
    ) external virtual override {
        address author = Core.$storage().posts[postId].author;
        require(msg.sender == author || _hasAccess(msg.sender, PID__REMOVE_POST), "MSG_SENDER_NOT_AUTHOR_NOR_HAS_ACCESS");
        Core._removePost(postId);
        _processPostRemoval(postId, customParams, feedRulesParams);
        address source = _processSourceStamp(postId, customParams);
        emit Lens_Feed_PostDeleted(postId, author, customParams, source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
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
        require(Core._postExists(postId), "POST_DOES_NOT_EXIST");
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

    function postExists(uint256 postId) external view override returns (bool) {
        return Core._postExists(postId);
    }

    function getPostAuthor(uint256 postId) external view override returns (address) {
        require(Core._postExists(postId), "POST_DOES_NOT_EXIST");
        return Core.$storage().posts[postId].author;
    }

    function getPostCount() external view override returns (uint256) {
        return Core.$storage().postCount;
    }

    function getPostCount(address author) external view override returns (uint256) {
        return Core.$storage().authorPostCount[author];
    }

    function getPostExtraData(uint256 postId, bytes32 key) external view override returns (bytes memory) {
        require(Core._postExists(postId), "POST_DOES_NOT_EXIST");
        address postAuthor = Core.$storage().posts[postId].author;
        return _getEntityExtraData(postAuthor, postId, key);
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getPrimitiveExtraData(key);
    }

    function getPostSequentialId(uint256 postId) external view override returns (uint256) {
        require(Core._postExists(postId), "POST_DOES_NOT_EXIST");
        return Core.$storage().posts[postId].postSequentialId;
    }

    function getAuthorPostSequentialId(uint256 postId) external view override returns (uint256) {
        require(Core._postExists(postId), "POST_DOES_NOT_EXIST");
        return Core.$storage().posts[postId].authorPostSequentialId;
    }

    function getNextPostId(address author) external view returns (uint256) {
        return Core._generatePostId(author, Core.$storage().authorPostCount[author] + 1);
    }
}
