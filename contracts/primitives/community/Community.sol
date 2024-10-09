// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICommunity} from "./ICommunity.sol";
import {CommunityCore as Core} from "./CommunityCore.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {RuleConfiguration, RuleExecutionData, DataElement} from "./../../types/Types.sol";
import {RuleBasedCommunity} from "./RuleBasedCommunity.sol";
import {AccessControlled} from "./../base/AccessControlled.sol";
import {Events} from "./../../types/Events.sol";

contract Community is ICommunity, RuleBasedCommunity, AccessControlled {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_RID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant REMOVE_MEMBER_RID = uint256(keccak256("REMOVE_MEMBER"));

    constructor(string memory metadataURI, IAccessControl accessControl) AccessControlled(accessControl) {
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Community_MetadataURISet(metadataURI);
        _emitRIDs();
        emit Events.Lens_Contract_Deployed("community", "lens.community", "community", "lens.community");
    }

    function _emitRIDs() internal override {
        super._emitRIDs();
        emit Lens_ResourceId_Available(SET_RULES_RID, "SET_RULES");
        emit Lens_ResourceId_Available(SET_METADATA_RID, "SET_METADATA");
        emit Lens_ResourceId_Available(SET_EXTRA_DATA_RID, "SET_EXTRA_DATA");
        emit Lens_ResourceId_Available(REMOVE_MEMBER_RID, "REMOVE_MEMBER");
    }

    // Access Controlled functions

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_RID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Community_MetadataURISet(metadataURI);
    }

    function addCommunityRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _addCommunityRule(rules[i]);
            emit Lens_Community_RuleAdded(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function updateCommunityRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _updateCommunityRule(rules[i]);
            emit Lens_Community_RuleUpdated(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function removeCommunityRules(address[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeCommunityRule(rules[i]);
            emit Lens_Community_RuleRemoved(rules[i]);
        }
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_RID);
        Core._setExtraData(extraDataToSet);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            emit Lens_Community_ExtraDataSet(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
        }
    }

    // Public functions

    function joinCommunity(address account, RuleExecutionData calldata communityRulesData) external override {
        require(msg.sender == account);
        uint256 membershipId = Core._grantMembership(account);
        _processJoining(account, membershipId, communityRulesData);
        emit Lens_Community_MemberJoined(account, membershipId, communityRulesData);
    }

    function leaveCommunity(address account, RuleExecutionData calldata communityRulesData) external override {
        require(msg.sender == account);
        uint256 membershipId = Core._revokeMembership(account);
        _processLeaving(account, membershipId, communityRulesData);
        emit Lens_Community_MemberLeft(account, membershipId, communityRulesData);
    }

    // TODO: Why don't we have addMember? Because we don't want to kidnap someone into the community?

    function removeMember(address account, RuleExecutionData calldata communityRulesData) external override {
        _requireAccess(msg.sender, REMOVE_MEMBER_RID);
        uint256 membershipId = Core._revokeMembership(account);
        _processRemoval(account, membershipId, communityRulesData);
        emit Lens_Community_MemberRemoved(account, membershipId, communityRulesData);
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

    function getCommunityRules(bool isRequired) external view override returns (address[] memory) {
        return _getCommunityRules(isRequired);
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().extraData[key];
    }
}
