// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IGroup} from "./../../interfaces/IGroup.sol";
import {GroupCore as Core} from "./GroupCore.sol";
import {IAccessControl} from "./../../interfaces/IAccessControl.sol";
import {
    RuleConfiguration,
    RuleOperation,
    RuleChange,
    RuleExecutionData,
    KeyValue,
    SourceStamp
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
    uint256 constant ADD_MEMBER_PID = uint256(keccak256("ADD_MEMBER"));
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
        emit Events.Lens_PermissionId_Available(ADD_MEMBER_PID, "ADD_MEMBER");
        emit Events.Lens_PermissionId_Available(REMOVE_MEMBER_PID, "REMOVE_MEMBER");
    }

    // Access Controlled functions

    function _beforeChangeGroupRules(RuleChange[] calldata ruleChanges) internal virtual override {
        _requireAccess(msg.sender, SET_RULES_PID);
    }

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Group_MetadataURISet(metadataURI);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = Core._setExtraData(extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    emit Lens_Group_ExtraDataRemoved(extraDataToSet[i].key);
                } else {
                    emit Lens_Group_ExtraDataUpdated(
                        extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                    );
                }
            } else if (!isNewValueEmpty) {
                emit Lens_Group_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            }
        }
    }

    // Public functions

    function addMember(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external override {
        uint256 membershipId = Core._grantMembership(account, sourceStamp.source);
        if (_amountOfRules(IGraphRules.processMemberAddition.selector) != 0) {
            _processMemberAddition(account, groupRulesData);
        } else {
            _requireAccess(msg.sender, ADD_MEMBER_PID);
        }
        _processSourceStamp(sourceStamp);
        emit Lens_Group_MemberAdded(account, membershipId, customParams, ruleProcessingParams, sourceStamp.source);
    }

    function removeMember(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external override {
        _requireAccess(msg.sender, REMOVE_MEMBER_PID);
        uint256 membershipId = Core._revokeMembership(account);
        _processRemoval(account, groupRulesData);
        _processSourceStamp(sourceStamp);
        emit Lens_Group_MemberRemoved(account, membershipId, customParams, ruleProcessingParams, sourceStamp.source);
    }

    function joinGroup(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external override {
        require(msg.sender == account);
        uint256 membershipId = Core._grantMembership(account, sourceStamp.source);
        _processJoining(account, groupRulesData);
        _processSourceStamp(sourceStamp);
        emit Lens_Group_MemberJoined(account, membershipId, customParams, ruleProcessingParams, sourceStamp.source);
    }

    function leaveGroup(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external override {
        require(msg.sender == account);
        uint256 membershipId = Core._revokeMembership(account);
        _processSourceStamp(sourceStamp);
        emit Lens_Group_MemberLeft(account, membershipId, customParams, ruleProcessingParams, sourceStamp.source);
    }

    function _processSourceStamp(SourceStamp calldata sourceStamp) internal {
        if (sourceStamp.source != address(0)) {
            ISource(sourceStamp.source).validateSource(sourceStamp);
        }
    }

    // bytes32 constant SOURCE_STAMP_CUSTOM_PARAM = keccak256("lens.core.sourceStamp");
    // bytes32 constant SOURCE_EXTRA_DATA = keccak256("lens.core.source");
    // function _processSourceStamp(KeyValue[] calldata customParams, bool storeSourceStamp) internal {
    //     for (uint256 i = 0; i < customParams.length; i++) {
    //         if (customParams[i].key == SOURCE_STAMP_CUSTOM_PARAM) {
    //             SourceStamp memory sourceStamp = abi.decode(customParams[i].value, (SourceStamp));
    //             ISource(sourceStamp.source).validateSource(sourceStamp);
    //             if (storeSourceStamp) {
    //                 // TODO: Create a new library for "extra storage" / "extra data"
    //                 _setExtraData(membershipId, KeyValue(SOURCE_EXTRA_DATA, abi.encode(sourceStamp.source)));
    //             }
    //         }
    //     }
    // }

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

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().extraData[key];
    }
}
