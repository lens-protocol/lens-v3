// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Membership, IGroup} from "contracts/core/interfaces/IGroup.sol";
import {GroupCore as Core} from "contracts/core/primitives/group/GroupCore.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedGroup} from "contracts/core/primitives/group/RuleBasedGroup.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraStorageBased} from "contracts/core/base/ExtraStorageBased.sol";
import {Events} from "contracts/core/types/Events.sol";
import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract Group is
    IGroup,
    Initializable,
    RuleBasedGroup,
    AccessControlled,
    ExtraStorageBased,
    SourceStampBased,
    MetadataBased
{
    // Resource IDs involved in the contract
    /// @custom:keccak lens.permission.SetMetadata
    uint256 constant PID__SET_METADATA = uint256(0xe40fdb273cda3c78f0d9b6d20f5378755989e26c60c89696e5eea644d84eefea);
    /// @custom:keccak lens.permission.ChangeRules
    uint256 constant PID__CHANGE_RULES = uint256(0x550b12ef6572134aefc5804fd2b13ab3d8451e067ad453f67afe134cffebd977);
    /// @custom:keccak lens.permission.SetExtraData
    uint256 constant PID__SET_EXTRA_DATA = uint256(0x9b4afa2e6d7162f878076bb1210736928cd607a384b985eca0dba5e94790e72a);
    /// @custom:keccak lens.permission.AddMember
    uint256 constant PID__ADD_MEMBER = uint256(0x19ef038b2d9618004143e998c9c636d9796ef58a03b5e2351e9f8d8446b0c2ab);
    /// @custom:keccak lens.permission.RemoveMember
    uint256 constant PID__REMOVE_MEMBER = uint256(0x8c204b72f1086f607fac077224053e94d5f8a69311195889c42430ffa8646e23);

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
        emit Events.Lens_Contract_Deployed("group", "lens.group", "group", "lens.group");
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Group_MetadataURISet(metadataURI);
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(PID__CHANGE_RULES, "lens.permission.ChangeRules");
        emit Events.Lens_PermissionId_Available(PID__SET_METADATA, "lens.permission.SetMetadata");
        emit Events.Lens_PermissionId_Available(PID__SET_EXTRA_DATA, "lens.permission.SetExtraData");
        emit Events.Lens_PermissionId_Available(PID__ADD_MEMBER, "lens.permission.AddMember");
        emit Events.Lens_PermissionId_Available(PID__REMOVE_MEMBER, "lens.permission.RemoveMember");
    }

    // Access Controlled functions

    function _beforeMetadataURIUpdate(string memory /* metadataURI */ ) internal view override {
        _requireAccess(msg.sender, PID__SET_METADATA);
    }

    function _beforeChangePrimitiveRules(RuleChange[] memory /* ruleChanges */ ) internal virtual override {
        _requireAccess(msg.sender, PID__CHANGE_RULES);
    }

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory ruleChanges)
        internal
        pure
        virtual
        override
    {}

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = _setPrimitiveExtraData(extraDataToSet[i]);
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
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external override {
        uint256 membershipId = Core._grantMembership(account);
        if (_amountOfRules(IGroupRule.processAddition.selector) != 0) {
            _processMemberAddition(msg.sender, account, customParams, ruleProcessingParams);
        } else {
            _requireAccess(msg.sender, PID__ADD_MEMBER);
        }
        address source = _processSourceStamp(membershipId, customParams);
        emit Lens_Group_MemberAdded(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function removeMember(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external override {
        _requireAccess(msg.sender, PID__REMOVE_MEMBER);
        uint256 membershipId = Core._revokeMembership(account);
        _processMemberRemoval(msg.sender, account, customParams, ruleProcessingParams);
        address source = _processSourceStamp(membershipId, customParams);
        emit Lens_Group_MemberRemoved(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function joinGroup(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external override {
        require(msg.sender == account, Errors.InvalidMsgSender());
        uint256 membershipId = Core._grantMembership(account);
        _processMemberJoining(msg.sender, account, customParams, ruleProcessingParams);
        address source = _processSourceStamp(membershipId, customParams);
        emit Lens_Group_MemberJoined(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function leaveGroup(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external override {
        require(msg.sender == account, Errors.InvalidMsgSender());
        uint256 membershipId = Core._revokeMembership(account);
        _processMemberLeaving(msg.sender, account, customParams, ruleProcessingParams);
        address source = _processSourceStamp(membershipId, customParams);
        emit Lens_Group_MemberLeft(account, membershipId, customParams, ruleProcessingParams, source);
    }

    // Getters

    function getNumberOfMembers() external view override returns (uint256) {
        return Core.$storage().numberOfMembers;
    }

    function isMember(address account) external view override returns (bool) {
        return Core._isMember(account);
    }

    function getMembership(address account) external view override returns (Membership memory) {
        Membership memory membership = Core._getMembership(account);
        require(membership.id != 0, Errors.DoesNotExist());
        return membership;
    }

    function getMembershipTimestamp(address account) external view override returns (uint256) {
        Membership memory membership = Core._getMembership(account);
        require(membership.id != 0, Errors.DoesNotExist());
        return membership.timestamp;
    }

    function getMembershipId(address account) external view override returns (uint256) {
        uint256 membershipId = Core.$storage().memberships[account].id;
        require(membershipId != 0, Errors.DoesNotExist());
        return membershipId;
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return _getPrimitiveExtraData(key);
    }
}
