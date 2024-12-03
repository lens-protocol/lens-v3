// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {Follow, IGraph} from "./../../interfaces/IGraph.sol";
import {GraphCore as Core} from "./GraphCore.sol";
import {IAccessControl} from "./../../interfaces/IAccessControl.sol";
import {
    RuleConfigurationParams,
    RuleOperation,
    RuleChange,
    RuleProcessingParams,
    KeyValue,
    SourceStamp
} from "./../../types/Types.sol";
import {RuleBasedGraph} from "./RuleBasedGraph.sol";
import {AccessControlled} from "./../../access/AccessControlled.sol";
import {Events} from "./../../types/Events.sol";
import {ISource} from "./../../interfaces/ISource.sol";

contract Graph is IGraph, RuleBasedGraph, AccessControlled {
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
            bool hadAValueSetBefore = Core._setExtraData(extraDataToSet[i]);
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
        uint256 followId,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams,
        RuleProcessingParams[] calldata followRulesProcessingParams,
        SourceStamp calldata sourceStamp
    ) external override returns (uint256) {
        require(msg.sender == followerAccount);
        uint256 assignedFollowId = Core._follow(followerAccount, accountToFollow, followId);
        _processSourceStamp(sourceStamp);
        _graphProcessFollow(msg.sender, followerAccount, accountToFollow, customParams, graphRulesProcessingParams);
        _accountProcessFollow(msg.sender, followerAccount, accountToFollow, customParams, followRulesProcessingParams);
        emit Lens_Graph_Followed(
            followerAccount,
            accountToFollow,
            assignedFollowId,
            customParams,
            graphRulesProcessingParams,
            followRulesProcessingParams,
            sourceStamp.source
        );
        return assignedFollowId;
    }

    function unfollow(
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams,
        SourceStamp calldata sourceStamp
    ) external override returns (uint256) {
        require(msg.sender == followerAccount);
        uint256 followId = Core._unfollow(followerAccount, accountToUnfollow);
        _processSourceStamp(sourceStamp);
        emit Lens_Graph_Unfollowed(
            followerAccount, accountToUnfollow, followId, customParams, graphRulesProcessingParams, sourceStamp.source
        );
        return followId;
    }

    function _processSourceStamp(SourceStamp calldata sourceStamp) internal {
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
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

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().extraData[key];
    }

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }
}
