// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Follow, IGraph} from "./IGraph.sol";
import {IFollowRule} from "./IFollowRule.sol";
import {IGraphRule} from "./IGraphRule.sol";
import {GraphCore as Core} from "./GraphCore.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {AccessControlLib} from "./../libraries/AccessControlLib.sol";
import {RuleConfiguration, DataElement} from "./../../types/Types.sol";
import {RuleBased} from "./../base/RuleBased.sol";

contract Graph is IGraph, RuleBased {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    // Resource IDs involved in the contract
    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_RID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant CHANGE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_ACCESS_CONTROL"));

    bytes32 public constant FOLLOW_RULE_STORAGE_KEY = keccak256("lens.graph.follow.rule.storage.key");

    constructor(string memory metadataURI, IAccessControl accessControl) RuleBased(bytes32(0)) {
        Core.$storage().metadataURI = metadataURI;
        Core.$storage().accessControl = address(accessControl);
        emit Lens_Graph_MetadataUriSet(metadataURI);
    }

    // Access Controlled functions

    // function setGraphRules(IGraphRule graphRules) external override {
    //     Core.$storage().accessControl.requireAccess(msg.sender, SET_RULES_RID);
    //     Core.$storage().graphRules = address(graphRules);
    //     emit Lens_Graph_RulesSet(address(graphRules));
    // }

    // TODO: This is a 1-step operation, while some of our AC owner transfers are a 2-step, or even 3-step operations.
    function setAccessControl(IAccessControl accessControl) external {
        // msg.sender must have permissions to change access control
        Core.$storage().accessControl.requireAccess(msg.sender, CHANGE_ACCESS_CONTROL_RID);
        accessControl.verifyHasAccessFunction();
        Core.$storage().accessControl = address(accessControl);
    }

    // Public user functions

    // TODO: For now we pass graphRulesData as a concatenation of Required[] + Optional[] arrays. Think if this is best.
    function addFollowRules(address account, RuleConfiguration[] calldata rules, bytes[] calldata graphRulesData)
        external
        override
    {
        require(msg.sender == account);
        address[] memory ruleAddresses = new address[](rules.length);
        for (uint256 i = 0; i < rules.length; i++) {
            // Passes the rule to add, and the call to do to configure the rule (account, configData)
            _addRule(
                FOLLOW_RULE_STORAGE_KEY,
                rules[i],
                abi.encodeWithSelector(IFollowRule.configure.selector, account, rules[i].configData)
            );
            ruleAddresses[i] = rules[i].ruleAddress;
            emit Lens_Graph_Follow_RuleAdded(account, rules[i].ruleAddress, rules[i]);
        }
        _processFollowRulesChange(account, ruleAddresses, graphRulesData);
    }

    function updateFollowRules(address account, RuleConfiguration[] calldata rules, bytes[] calldata graphRulesData)
        external
        override
    {
        require(msg.sender == account);
        address[] memory ruleAddresses = new address[](rules.length);
        for (uint256 i = 0; i < rules.length; i++) {
            // Passes the rule to add, and the call to do to configure the rule (account, configData)
            _updateRule(
                FOLLOW_RULE_STORAGE_KEY,
                rules[i],
                abi.encodeWithSelector(IFollowRule.configure.selector, account, rules[i].configData)
            );
            ruleAddresses[i] = rules[i].ruleAddress;
            emit Lens_Graph_Follow_RuleUpdated(account, rules[i].ruleAddress, rules[i]);
        }
        _processFollowRulesChange(account, ruleAddresses, graphRulesData);
    }

    function removeFollowRules(address account, address[] calldata rules, bytes[] calldata graphRulesData)
        external
        override
    {
        require(msg.sender == account);
        for (uint256 i = 0; i < rules.length; i++) {
            // Passes the rule to add, and the call to do to configure the rule (account, configData)
            _removeRule(FOLLOW_RULE_STORAGE_KEY, rules[i]);
            emit Lens_Graph_Follow_RuleRemoved(account, rules[i]);
        }
        _processFollowRulesChange(account, rules, graphRulesData);
    }

    function follow(
        address followerAccount,
        address targetAccount,
        uint256 followId,
        bytes calldata graphRulesData,
        bytes calldata followRulesData
    ) public returns (uint256) {
        require(msg.sender == followerAccount);
        uint256 assignedFollowId = Core._follow(followerAccount, targetAccount, followId);
        if (address(Core.$storage().graphRules) != address(0)) {
            IGraphRule(Core.$storage().graphRules).processFollow(
                msg.sender, followerAccount, targetAccount, assignedFollowId, graphRulesData
            );
        }
        if (address(Core.$storage().followRules[targetAccount]) != address(0)) {
            IFollowRule(Core.$storage().followRules[targetAccount]).processFollow(
                msg.sender, followerAccount, assignedFollowId, followRulesData
            );
        }
        emit Lens_Graph_Followed(followerAccount, targetAccount, assignedFollowId, graphRulesData, followRulesData);
        return assignedFollowId;
    }

    function unfollow(address followerAccount, address targetAccount, bytes calldata graphRulesData)
        public
        returns (uint256)
    {
        require(msg.sender == followerAccount);
        uint256 followId = Core._unfollow(followerAccount, targetAccount);
        if (address(Core.$storage().graphRules) != address(0)) {
            IGraphRule(Core.$storage().graphRules).processUnfollow(
                msg.sender, followerAccount, targetAccount, followId, graphRulesData
            );
        }
        emit Lens_Graph_Unfollowed(followerAccount, targetAccount, followId, graphRulesData);
        return followId;
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        Core.$storage().accessControl.requireAccess(msg.sender, SET_EXTRA_DATA_RID);
        Core._setExtraData(extraDataToSet);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            emit Lens_Graph_ExtraDataSet(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
        }
    }

    // Internal

    function _processFollowRulesChange(address account, address[] memory rules, bytes[] calldata graphRulesData)
        internal
    {
        if (address(Core.$storage().graphRules) != address(0)) {
            bytes[] memory graphRulesEncodedDatas = new bytes[](graphRulesData.length);
            for (uint256 i = 0; i < graphRulesData.length; i++) {
                graphRulesEncodedDatas[i] =
                    abi.encodeWithSelector(IGraphRule.processFollowRulesChange.selector, account, rules, graphRulesData);
            }
            _processRules(graphRulesEncodedDatas);
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

    function getFollowRules(address account) external view override returns (IFollowRule) {
        return IFollowRule(Core.$storage().followRules[account]);
    }

    function getFollowersCount(address account) external view override returns (uint256) {
        return Core.$storage().followersCount[account];
    }

    function getGraphRules() external view override returns (IGraphRule) {
        return IGraphRule(Core.$storage().graphRules);
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().extraData[key];
    }
}
