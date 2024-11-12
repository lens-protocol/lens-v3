// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroup} from "./../../interfaces/IGroup.sol";
import {GroupCore as Core} from "./GroupCore.sol";
import {IAccessControl} from "./../../interfaces/IAccessControl.sol";
import {
    RuleConfiguration, RuleExecutionData, DataElement, DataElementValue, SourceStamp
} from "./../../types/Types.sol";
import {RuleBasedGroup} from "./RuleBasedGroup.sol";
import {AccessControlled} from "./../../access//AccessControlled.sol";
import {Events} from "./../../types/Events.sol";
import {ISource} from "./../../interfaces/ISource.sol";

contract Group is IGroup, RuleBasedGroup, AccessControlled {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_PID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_PID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_PID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant REMOVE_MEMBER_PID = uint256(keccak256("REMOVE_MEMBER"));

    constructor(string memory metadataURI, IAccessControl accessControl) AccessControlled(accessControl) {
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Group_MetadataURISet(metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed("group", "lens.group", "group", "lens.group");
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(SET_RULES_PID, "SET_RULES");
        emit Events.Lens_PermissionId_Available(SET_METADATA_PID, "SET_METADATA");
        emit Events.Lens_PermissionId_Available(SET_EXTRA_DATA_PID, "SET_EXTRA_DATA");
        emit Events.Lens_PermissionId_Available(REMOVE_MEMBER_PID, "REMOVE_MEMBER");
    }

    // Access Controlled functions

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Group_MetadataURISet(metadataURI);
    }

    function addGroupRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < rules.length; i++) {
            _addGroupRule(rules[i]);
            emit Lens_Group_RuleAdded(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function updateGroupRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < rules.length; i++) {
            _updateGroupRule(rules[i]);
            emit Lens_Group_RuleUpdated(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function removeGroupRules(address[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_PID);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeGroupRule(rules[i]);
            emit Lens_Group_RuleRemoved(rules[i]);
        }
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool wasExtraDataAlreadySet = Core._setExtraData(extraDataToSet[i]);
            if (wasExtraDataAlreadySet) {
                emit Lens_Group_ExtraDataUpdated(
                    extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                );
            } else {
                emit Lens_Group_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            }
        }
    }

    function removeExtraData(bytes32[] calldata extraDataKeysToRemove) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataKeysToRemove.length; i++) {
            Core._removeExtraData(extraDataKeysToRemove[i]);
            emit Lens_Group_ExtraDataRemoved(extraDataKeysToRemove[i]);
        }
    }

    // Public functions

    function joinGroup(address account, RuleExecutionData calldata groupRulesData, SourceStamp calldata sourceStamp)
        external
        override
    {
        require(msg.sender == account);
        uint256 membershipId = Core._grantMembership(account, sourceStamp.source);
        _processJoining(account, membershipId, groupRulesData);
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        emit Lens_Group_MemberJoined(account, membershipId, groupRulesData, sourceStamp.source);
    }

    function leaveGroup(address account, RuleExecutionData calldata groupRulesData, SourceStamp calldata sourceStamp)
        external
        override
    {
        require(msg.sender == account);
        uint256 membershipId = Core._revokeMembership(account);
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        emit Lens_Group_MemberLeft(account, membershipId, groupRulesData, sourceStamp.source);
    }

    // TODO: Why don't we have addMember? Because we don't want to kidnap someone into the group?

    function removeMember(address account, RuleExecutionData calldata groupRulesData, SourceStamp calldata sourceStamp)
        external
        override
    {
        _requireAccess(msg.sender, REMOVE_MEMBER_PID);
        uint256 membershipId = Core._revokeMembership(account);
        _processRemoval(account, membershipId, groupRulesData);
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
        emit Lens_Group_MemberRemoved(account, membershipId, groupRulesData, sourceStamp.source);
    }

    // Getters

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }

    function getNumberOfMembers() external view override returns (uint256) {
        return Core.$storage().numberOfMembers;
    }

    function getMembershipTimestamp(address account) external view override returns (uint256) {
        return Core.$storage().memberships[account].timestamp;
    }

    function getMembershipId(address account) external view override returns (uint256) {
        return Core.$storage().memberships[account].id;
    }

    function getGroupRules(bool isRequired) external view override returns (address[] memory) {
        return _getGroupRules(isRequired);
    }

    function getExtraData(bytes32 key) external view override returns (DataElementValue memory) {
        return Core.$storage().extraData[key];
    }
}