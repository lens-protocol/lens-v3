// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Follow, IGraph} from "contracts/core/interfaces/IGraph.sol";
import {GraphCore as Core} from "contracts/core/primitives/graph/GraphCore.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedGraph} from "contracts/core/primitives/graph/RuleBasedGraph.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {Events} from "contracts/core/types/Events.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract Graph is
    IGraph,
    Initializable,
    RuleBasedGraph,
    AccessControlled,
    ExtraDataBased,
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

    /// @custom:keccak lens.entityType.Follow
    bytes32 constant ENTITY_TYPE__FOLLOW = 0x36d2d2080fb90910eb85e01c8f8dd668252334986cbeed5f3f2a0d51ae9a49fb;

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
        emit Events.Lens_Contract_Deployed({contractType: "lens.contract.Graph", flavour: "lens.contract.Graph"});
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal override {
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

    function _beforeChangePrimitiveRules(RuleChange[] memory /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, PID__CHANGE_RULES);
    }

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory /* ruleChanges */ )
        internal
        virtual
        override
    {
        require(msg.sender == address(uint160(entityId)), Errors.InvalidMsgSender()); // Follow rules can only be changed in your own account
    }

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Lens_Graph_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Lens_Graph_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Lens_Graph_ExtraDataRemoved(extraDataRemoved.key);
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
        require(msg.sender == followerAccount, Errors.InvalidMsgSender());
        // If some implementation wants to allow followId specification, it can be implemented using customParams.
        uint256 assignedFollowId = Core._follow(followerAccount, accountToFollow, 0, block.timestamp);
        address source = _processSourceStamp(_getFollowEntityType(accountToFollow), assignedFollowId, customParams);
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
        require(msg.sender == followerAccount, Errors.InvalidMsgSender());
        uint256 followId = Core._unfollow(followerAccount, accountToUnfollow);
        address source = _processSourceStamp(customParams);
        _graphProcessUnfollow(msg.sender, followerAccount, accountToUnfollow, customParams, graphRulesProcessingParams);
        /**
         * Clears follow source when unfollowing. A Graph primitive implementation that tokenizes follows might want to
         * store an additional DATA__CREATION_SOURCE for when the first follow, which minted the token, was done, and
         * keep it until the follow token is burnt.
         */
        _clearSource(_getFollowEntityType(accountToUnfollow), followId);
        emit Lens_Graph_Unfollowed(
            followerAccount, accountToUnfollow, followId, customParams, graphRulesProcessingParams, source
        );
        return followId;
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    function _getFollowEntityType(address targetAccount) internal pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(ENTITY_TYPE__FOLLOW, targetAccount)));
    }

    // Getters

    function isFollowing(address followerAccount, address targetAccount) external view override returns (bool) {
        return Core.$storage().follows[followerAccount][targetAccount].id != 0;
    }

    function getFollowerById(address account, uint256 followId) external view override returns (address) {
        address follower = Core.$storage().followers[account][followId];
        require(follower != address(0), Errors.DoesNotExist());
        return follower;
    }

    function getFollow(address followerAccount, address targetAccount) external view override returns (Follow memory) {
        Follow memory followData = Core.$storage().follows[followerAccount][targetAccount];
        require(followData.id != 0, Errors.DoesNotExist());
        return followData;
    }

    function getFollowersCount(address account) external view override returns (uint256) {
        return Core.$storage().followersCount[account];
    }

    function getFollowingCount(address account) external view override returns (uint256) {
        return Core.$storage().followingCount[account];
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getExtraData(key);
    }

    function getFollowSource(address followedAccount, uint256 followId) external view override returns (address) {
        return _getSource(_getFollowEntityType(followedAccount), followId);
    }
}
