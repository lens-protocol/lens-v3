// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {Follow, IGraph} from "./../../interfaces/IGraph.sol";
import {GraphCore as Core} from "./GraphCore.sol";
import {IAccessControl} from "./../../interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "./../../types/Types.sol";
import {RuleBasedGraph} from "./RuleBasedGraph.sol";
import {AccessControlled} from "./../../access/AccessControlled.sol";
import {ExtraStorageBased} from "./../../base/ExtraStorageBased.sol";
import {Events} from "./../../types/Events.sol";
import {SourceStampBased} from "./../../base/SourceStampBased.sol";

contract Graph is IGraph, RuleBasedGraph, AccessControlled, ExtraStorageBased, SourceStampBased {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_PID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_PID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_PID = uint256(keccak256("SET_EXTRA_DATA"));

    // uint256 constant SKIP_FOLLOW_RULES_CHECKS_PID = uint256(keccak256("SKIP_FOLLOW_RULES_CHECKS"));

    constructor(string memory metadataURI, IAccessControl accessControl) AccessControlled(accessControl) {
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Graph_MetadataURISet(metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed("graph", "lens.graph", "graph", "lens.graph");
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(SET_RULES_PID, "SET_RULES");
        emit Events.Lens_PermissionId_Available(SET_METADATA_PID, "SET_METADATA");
        emit Events.Lens_PermissionId_Available(SET_EXTRA_DATA_PID, "SET_EXTRA_DATA");
    }

    // Access Controlled functions

    function _beforeChangeGraphRules(RuleChange[] calldata /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, SET_RULES_PID);
    }

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Graph_MetadataURISet(metadataURI);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setPrimitiveExtraData(extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    emit Lens_Graph_ExtraDataRemoved(extraDataToSet[i].key);
                } else {
                    emit Lens_Graph_ExtraDataUpdated(
                        extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                    );
                }
            } else if (!isNewValueEmpty) {
                emit Lens_Graph_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            }
        }
    }

    // Public functions

    function follow(
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams,
        RuleProcessingParams[] calldata followRulesProcessingParams
    ) external override returns (uint256) {
        require(msg.sender == followerAccount);
        // followId is now in customParams - think if we want to implement this now, or later. For now passing 0 always.
        uint256 assignedFollowId = Core._follow(followerAccount, accountToFollow, 0);
        address source = _processSourceStamp(assignedFollowId, customParams);
        _graphProcessFollow(msg.sender, followerAccount, accountToFollow, customParams, graphRulesProcessingParams);
        _accountProcessFollow(msg.sender, followerAccount, accountToFollow, customParams, followRulesProcessingParams);
        emit Lens_Graph_Followed(
            followerAccount,
            accountToFollow,
            assignedFollowId,
            customParams,
            graphRulesProcessingParams,
            followRulesProcessingParams,
            source
        );
        return assignedFollowId;
    }

    function unfollow(
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external override returns (uint256) {
        require(msg.sender == followerAccount);
        uint256 followId = Core._unfollow(followerAccount, accountToUnfollow);
        address source = _processSourceStamp(followId, customParams);
        _graphProcessUnfollow(msg.sender, followerAccount, accountToUnfollow, customParams, graphRulesProcessingParams);
        emit Lens_Graph_Unfollowed(
            followerAccount, accountToUnfollow, followId, customParams, graphRulesProcessingParams, source
        );
        return followId;
    }

    // Getters

    function isFollowing(address followerAccount, address targetAccount) external view override returns (bool) {
        return Core.$storage().follows[followerAccount][targetAccount].id != 0;
    }

    function getFollowerById(address account, uint256 followId) external view override returns (address) {
        return Core.$storage().followers[account][followId];
    }

    function getFollow(address followerAccount, address targetAccount) external view override returns (Follow memory) {
        return Core.$storage().follows[followerAccount][targetAccount];
    }

    function getFollowersCount(address account) external view override returns (uint256) {
        return Core.$storage().followersCount[account];
    }

    function getFollowingCount(address account) external view override returns (uint256) {
        return Core.$storage().followingCount[account];
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getPrimitiveExtraData(key);
    }

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }
}
