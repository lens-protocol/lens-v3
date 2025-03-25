// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Membership, IGroup} from "contracts/core/interfaces/IGroup.sol";
import {GroupCore as Core} from "contracts/core/primitives/group/GroupCore.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {RuleChange, RuleProcessingParams, KeyValue} from "contracts/core/types/Types.sol";
import {RuleBasedGroup} from "contracts/core/primitives/group/RuleBasedGroup.sol";
import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {ExtraDataBased} from "contracts/core/base/ExtraDataBased.sol";
import {Events} from "contracts/core/types/Events.sol";
import {IGroupRule} from "contracts/core/interfaces/IGroupRule.sol";
import {SourceStampBased} from "contracts/core/base/SourceStampBased.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {IAccountGroupAdditionSettings} from "contracts/core/interfaces/IAccountGroupAdditionSettings.sol";
import {KeyValueLib} from "contracts/core/libraries/KeyValueLib.sol";

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
/// @custom:keccak lens.permission.SkipAddMemberRules
uint256 constant PID__SKIP_ADD_MEMBER_RULES = uint256(0xd2a5a9d31c1be4f87f450917f4a33dadddde87ef034ecd45fa79c2067bb0b434);
/// @custom:keccak lens.permission.SkipRemoveMemberRules
uint256 constant PID__SKIP_REMOVE_MEMBER_RULES =
    uint256(0x2c3e2cd5ab51b79b73a15b273d9b9ccfee8d62a91defe98fd96370db5e5564e0);

/// @custom:keccak lens.param.accountAdditionSettingsParams
bytes32 constant PARAM__ACCOUNT_ADDITION_SETTINGS_PARAMS =
    0xc5602d6fdc6b403d800fd4d9c15c7ff231b8994478f8df567d4554ab356cdd55;

contract Group is
    IGroup,
    Initializable,
    RuleBasedGroup,
    AccessControlled,
    ExtraDataBased,
    SourceStampBased,
    MetadataBased
{
    using KeyValueLib for KeyValue[];

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory metadataURI, IAccessControl accessControl, address foundingMember)
        external
        override
        initializer
    {
        _initialize(metadataURI, foundingMember);
        AccessControlled._initialize(accessControl);
    }

    function _initialize(string memory metadataURI, address foundingMember) internal {
        _setMetadataURI(metadataURI);
        _emitPIDs();
        emit Events.Lens_Contract_Deployed({contractType: "lens.contract.Group", flavour: "lens.contract.Group"});
        if (foundingMember != address(0)) {
            emit Lens_Group_MemberAdded(
                foundingMember,
                Core._grantMembership(foundingMember),
                new KeyValue[](0),
                new RuleProcessingParams[](0),
                address(0)
            );
        }
    }

    function _emitMetadataURISet(string memory metadataURI, address /* source */ ) internal override {
        emit Lens_Group_MetadataURISet(metadataURI);
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

    function _beforeChangeEntityRules(uint256 entityId, RuleChange[] memory ruleChanges)
        internal
        pure
        virtual
        override
    {}

    function _emitExtraDataAddedEvent(KeyValue calldata extraDataAdded) internal override {
        emit Lens_Group_ExtraDataAdded(extraDataAdded.key, extraDataAdded.value, extraDataAdded.value);
    }

    function _emitExtraDataUpdatedEvent(KeyValue calldata extraDataUpdated) internal override {
        emit Lens_Group_ExtraDataUpdated(extraDataUpdated.key, extraDataUpdated.value, extraDataUpdated.value);
    }

    function _emitExtraDataRemovedEvent(KeyValue calldata extraDataRemoved) internal override {
        emit Lens_Group_ExtraDataRemoved(extraDataRemoved.key);
    }

    // Public functions

    function addMember(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external override {
        _addMember(account, customParams, ruleProcessingParams, _processSourceStamp(customParams));
    }

    function removeMember(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external override {
        _removeMember(account, customParams, ruleProcessingParams, _processSourceStamp(customParams));
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
        address source = _processSourceStamp(customParams);
        _clearSource(membershipId);
        emit Lens_Group_MemberLeft(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, PID__SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    function _addMember(
        address account,
        KeyValue[] memory customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal {
        uint256 membershipId = Core._grantMembership(account);
        _processMemberAddition(msg.sender, account, customParams, ruleProcessingParams);
        // We require accounts to allow being added to the group; EOAs are expected to fail under this condition.
        require(
            IAccountGroupAdditionSettings(account).canBeAddedToGroup({
                group: address(this),
                addedBy: msg.sender,
                params: _extractAccountAdditionSettingsParamsFromParams(customParams)
            }),
            Errors.NotAllowed()
        );
        _storeSource(membershipId, source);
        emit Lens_Group_MemberAdded(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function _removeMember(
        address account,
        KeyValue[] memory customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        address source
    ) internal {
        uint256 membershipId = Core._revokeMembership(account);
        _processMemberRemoval(msg.sender, account, customParams, ruleProcessingParams);
        _clearSource(membershipId);
        emit Lens_Group_MemberRemoved(account, membershipId, customParams, ruleProcessingParams, source);
    }

    function _extractAccountAdditionSettingsParamsFromParams(KeyValue[] memory customParams)
        internal
        pure
        returns (KeyValue[] memory)
    {
        for (uint256 i = 0; i < customParams.length; i++) {
            if (customParams[i].key == PARAM__ACCOUNT_ADDITION_SETTINGS_PARAMS) {
                return abi.decode(customParams[i].value, (KeyValue[]));
            }
        }
        return new KeyValue[](0);
    }

    // Batch operations

    struct MemberBatchParams {
        address account;
        KeyValue[] customParams;
        RuleProcessingParams[] ruleProcessingParams;
    }

    function addMembers(MemberBatchParams[] calldata membersToAdd, KeyValue[] calldata customParams) external {
        address source = _processSourceStamp(customParams);
        for (uint256 i = 0; i < membersToAdd.length; i++) {
            _addMember(
                membersToAdd[i].account,
                customParams.concat(membersToAdd[i].customParams),
                membersToAdd[i].ruleProcessingParams,
                source
            );
        }
    }

    function removeMembers(MemberBatchParams[] calldata membersToRemove, KeyValue[] calldata customParams) external {
        address source = _processSourceStamp(customParams);
        for (uint256 i = 0; i < membersToRemove.length; i++) {
            _removeMember(
                membersToRemove[i].account,
                customParams.concat(membersToRemove[i].customParams),
                membersToRemove[i].ruleProcessingParams,
                source
            );
        }
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
        return _getExtraData(key);
    }

    function getMembershipSource(uint256 membershipId) external view override returns (address) {
        return _getSource(membershipId);
    }
}
