// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Follow, IGraph} from "./IGraph.sol";
import {GraphCore as Core} from "./GraphCore.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {RuleConfiguration, RuleExecutionData, DataElement} from "./../../types/Types.sol";
import {RuleBasedGraph} from "./RuleBasedGraph.sol";
import {AccessControlled} from "./../base/AccessControlled.sol";
import {Events} from "./../../types/Events.sol";

contract Graph is IGraph, RuleBasedGraph, AccessControlled {
    // Resource IDs involved in the contract
    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_RID = uint256(keccak256("SET_EXTRA_DATA"));

    // uint256 constant SKIP_FOLLOW_RULES_CHECKS_RID = uint256(keccak256("SKIP_FOLLOW_RULES_CHECKS"));

    constructor(string memory metadataURI, IAccessControl accessControl) AccessControlled(accessControl) {
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Graph_MetadataURISet(metadataURI);
        _emitRIDs();
        emit Events.Lens_Contract_Deployed("graph", "lens.graph", "graph", "lens.graph");
    }

    function _emitRIDs() internal override {
        super._emitRIDs();
        emit Lens_ResourceId_Available(SET_RULES_RID, "SET_RULES");
        emit Lens_ResourceId_Available(SET_METADATA_RID, "SET_METADATA");
        emit Lens_ResourceId_Available(SET_EXTRA_DATA_RID, "SET_EXTRA_DATA");
    }

    // Access Controlled functions

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_RID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Graph_MetadataURISet(metadataURI);
    }

    function addGraphRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _addGraphRule(rules[i]);
            emit Lens_Graph_RuleAdded(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function updateGraphRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _updateGraphRule(rules[i]);
            emit Lens_Graph_RuleUpdated(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function removeGraphRules(address[] calldata rules) external override {
        _requireAccess(msg.sender, SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeGraphRule(rules[i]);
            emit Lens_Graph_RuleRemoved(rules[i]);
        }
    }

    // Public functions

    function addFollowRules(
        address account,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata graphRulesData
    ) external override {
        // TODO: Decide if we want a RID to skip checks for owners/admins
        // require(msg.sender == account || _hasAccess(SKIP_FOLLOW_RULES_CHECKS_RID));
        require(msg.sender == account);
        address[] memory ruleAddresses = new address[](rules.length);
        for (uint256 i = 0; i < rules.length; i++) {
            _addFollowRule(account, rules[i]);
            ruleAddresses[i] = rules[i].ruleAddress;
            emit Lens_Graph_Follow_RuleAdded(account, rules[i].ruleAddress, rules[i]);
        }
        // if (_hasAccess(SKIP_FOLLOW_RULES_CHECKS_RID)) {
        //     return; // Skip processing the graph rules if you have the right access
        // }
        _graphProcessFollowRulesChange(account, ruleAddresses, graphRulesData);
    }

    function updateFollowRules(
        address account,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata graphRulesData
    ) external override {
        require(msg.sender == account);
        address[] memory ruleAddresses = new address[](rules.length);
        for (uint256 i = 0; i < rules.length; i++) {
            _updateFollowRule(account, rules[i]);
            ruleAddresses[i] = rules[i].ruleAddress;
            emit Lens_Graph_Follow_RuleUpdated(account, rules[i].ruleAddress, rules[i]);
        }
        _graphProcessFollowRulesChange(account, ruleAddresses, graphRulesData);
    }

    function removeFollowRules(address account, address[] calldata rules, RuleExecutionData calldata graphRulesData)
        external
        override
    {
        require(msg.sender == account);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeFollowRule(account, rules[i]);
            emit Lens_Graph_Follow_RuleRemoved(account, rules[i]);
        }
        _graphProcessFollowRulesChange(account, rules, graphRulesData);
    }

    function follow(
        address followerAccount,
        address accountToFollow,
        uint256 followId,
        RuleExecutionData calldata graphRulesData,
        RuleExecutionData calldata followRulesData
    ) external override returns (uint256) {
        require(msg.sender == followerAccount);
        uint256 assignedFollowId = Core._follow(followerAccount, accountToFollow, followId);
        _graphProcessFollow(followerAccount, accountToFollow, followId, graphRulesData);
        _accountProcessFollow(followerAccount, accountToFollow, followId, followRulesData);
        emit Lens_Graph_Followed(followerAccount, accountToFollow, assignedFollowId, graphRulesData, followRulesData);
        return assignedFollowId;
    }

    function unfollow(address followerAccount, address accountToUnfollow, RuleExecutionData calldata graphRulesData)
        external
        override
        returns (uint256)
    {
        require(msg.sender == followerAccount);
        uint256 followId = Core._unfollow(followerAccount, accountToUnfollow);
        _graphProcessUnfollow(followerAccount, accountToUnfollow, followId, graphRulesData);
        emit Lens_Graph_Unfollowed(followerAccount, accountToUnfollow, followId, graphRulesData);
        return followId;
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_RID);
        Core._setExtraData(extraDataToSet);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            emit Lens_Graph_ExtraDataSet(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
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

    function getGraphRules(bool isRequired) external view override returns (address[] memory) {
        return _getGraphRules(isRequired);
    }

    function getFollowRules(address account, bool isRequired) external view override returns (address[] memory) {
        return _getFollowRules(account, isRequired);
    }

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }
}
