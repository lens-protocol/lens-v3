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
import {MetadataBased} from "./../../base/MetadataBased.sol";
import {Initializable} from "./../../upgradeability/Initializable.sol";

contract Graph is
    IGraph,
    Initializable,
    RuleBasedGraph,
    AccessControlled,
    ExtraStorageBased,
    SourceStampBased,
    MetadataBased
{
    // Resource IDs involved in the contract

    /// @custom:keccak lens.permission.ChangeRules
    uint256 constant PID__CHANGE_RULES = uint256(0x550b12ef6572134aefc5804fd2b13ab3d8451e067ad453f67afe134cffebd977);
    /// @custom:keccak lens.permission.SetMetadata
    uint256 constant PID__SET_METADATA = uint256(0xe40fdb273cda3c78f0d9b6d20f5378755989e26c60c89696e5eea644d84eefea);
    /// @custom:keccak lens.permission.SetExtraData
    uint256 constant PID__SET_EXTRA_DATA = uint256(0x9b4afa2e6d7162f878076bb1210736928cd607a384b985eca0dba5e94790e72a);

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory metadataURI, IAccessControl accessControl) external override initializer {
        _initialize(metadataURI);
        AccessControlled._initialize(accessControl);
    }

    function _initialize(string memory metadataURI) internal {
        _setMetadataURI(metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed("graph", "lens.graph", "graph", "lens.graph");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Graph_MetadataURISet(metadataURI);
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(PID__CHANGE_RULES, "lens.permission.ChangeRules");
        emit Events.Lens_PermissionId_Available(PID__SET_METADATA, "lens.permission.SetMetadata");
        emit Events.Lens_PermissionId_Available(PID__SET_EXTRA_DATA, "lens.permission.SetExtraData");
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
        require(msg.sender == address(uint160(entityId))); // Follow rules can only be changed in your own account
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
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
        RuleProcessingParams[] calldata followRulesProcessingParams,
        KeyValue[] calldata extraData
    ) external virtual override returns (uint256) {
        require(msg.sender == followerAccount);
        // followId is now in customParams - think if we want to implement this now, or later. For now passing 0 always.
        uint256 assignedFollowId = Core._follow(followerAccount, accountToFollow, 0, block.timestamp);
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
            source,
            extraData
        );
        return assignedFollowId;
    }

    function unfollow(
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external virtual override returns (uint256) {
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
        address follower = Core.$storage().followers[account][followId];
        require(follower != address(0), "FOLLOWER_DOES_NOT_EXIST");
        return follower;
    }

    function getFollow(address followerAccount, address targetAccount) external view override returns (Follow memory) {
        Follow memory followData = Core.$storage().follows[followerAccount][targetAccount];
        require(followData.id != 0, "FOLLOW_DOES_NOT_EXIST");
        return followData;
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
}
