// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Follow, IGraph} from "./IGraph.sol";
import {IFollowRule} from "./IFollowRule.sol";
import {IGraphRule} from "./IGraphRule.sol";
import {GraphCore as Core} from "./GraphCore.sol";
import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {AccessControlLib} from "./../libraries/AccessControlLib.sol";
import {RuleConfiguration, RuleExecutionData, DataElement} from "./../../types/Types.sol";
import {RuleBased} from "./../base/RuleBased.sol";
import {AccessControlled} from "./../base/AccessControlled.sol";
import {ExtraData} from "./../base/ExtraData.sol";

contract Graph is IGraph, RuleBased, AccessControlled, ExtraData {
    using AccessControlLib for IAccessControl;
    using AccessControlLib for address;

    // Resource IDs involved in the contract
    uint256 constant SET_RULES_RID = uint256(keccak256("SET_RULES"));
    uint256 constant SET_METADATA_RID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_EXTRA_DATA_RID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant CHANGE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_ACCESS_CONTROL"));
    uint256 constant SKIP_FOLLOW_RULES_CHECKS_RID = uint256(keccak256("SKIP_FOLLOW_RULES_CHECKS"));
    uint256 constant OVERRIDE_FOLLOW_RID = uint256(keccak256("OVERRIDE_FOLLOW"));

    /////////////

    bytes32 public constant FOLLOW_RULE_STORAGE_KEY = keccak256("lens.graph.follow.rule.storage.key");

    constructor(string memory metadataURI, IAccessControl accessControl)
        RuleBased(bytes32(0))
        AccessControlled(accessControl)
    {
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Graph_MetadataUriSet(metadataURI);
    }

    // Access Controlled functions

    // TODO: This is a 1-step operation, while some of our AC owner transfers are a 2-step, or even 3-step operations.
    // function setAccessControl(IAccessControl accessControl) external override {
    //     // msg.sender must have permissions to change access control
    //     Core.$storage().accessControl.requireAccess(msg.sender, CHANGE_ACCESS_CONTROL_RID);
    //     accessControl.verifyHasAccessFunction();
    //     Core.$storage().accessControl = address(accessControl);
    // }

    function addGraphRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _addRule(rules[i]);
            emit Lens_Graph_RuleAdded(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function updateGraphRules(RuleConfiguration[] calldata rules) external override {
        _requireAccess(SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _updateRule(rules[i]);
            emit Lens_Graph_RuleUpdated(rules[i].ruleAddress, rules[i].configData, rules[i].isRequired);
        }
    }

    function removeGraphRules(address[] calldata rules) external override {
        _requireAccess(SET_RULES_RID);
        for (uint256 i = 0; i < rules.length; i++) {
            _removeRule(rules[i]);
            emit Lens_Graph_RuleRemoved(rules[i]);
        }
    }

    function setExtraData(DataElement[] calldata extraDataToSet) external override {
        _requireAccess(SET_EXTRA_DATA_RID);
        _setExtraData(extraDataToSet);
    }

    function setMetadataUri(string calldata metadataURI) external override {
        _requireAccess(SET_METADATA_RID);
        Core.$storage().metadataURI = metadataURI;
        emit Lens_Graph_MetadataUriSet(metadataURI);
    }

    // Public user functions

    function addFollowRules(
        address account,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata graphRulesData
    ) external override {
        require(msg.sender == account || _hasAccess(SKIP_FOLLOW_RULES_CHECKS_RID));
        address[] memory ruleAddresses = new address[](rules.length); // local array to pass into event
        bytes32 followRuleKey = _getFollowRuleKeyByAccount(account);
        for (uint256 i = 0; i < rules.length; i++) {
            // Passes the rule to add, and the call to do to configure the rule (account, configData)
            _addRule(followRuleKey, IFollowRule.CONFIGURE_SELECTOR, abi.encode(account), rules[i].configData);
            ruleAddresses[i] = rules[i].ruleAddress;
            emit Lens_Graph_Follow_RuleAdded(account, rules[i].ruleAddress, rules[i]);
        }
        _processRules(IGraphRule.FOLLOW_RULES_CHANGE_SELECTOR, abi.encode(account, ruleAddresses), graphRulesData);
    }

    function updateFollowRules(
        address account,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata graphRulesData
    ) external override {
        require(msg.sender == account || _hasAccess(SKIP_FOLLOW_RULES_CHECKS_RID));
        address[] memory ruleAddresses = new address[](rules.length);
        bytes32 followRuleKey = _getFollowRuleKeyByAccount(account);
        for (uint256 i = 0; i < rules.length; i++) {
            // Passes the rule to add, and the call to do to configure the rule (account, configData)
            _updateRule(followRuleKey, IFollowRule.CONFIGURE_SELECTOR, abi.encode(account), rules[i].configData);
            ruleAddresses[i] = rules[i].ruleAddress;
            emit Lens_Graph_Follow_RuleUpdated(account, rules[i].ruleAddress, rules[i]);
        }
        _processRules(IGraphRule.FOLLOW_RULES_CHANGE_SELECTOR, abi.encode(account, ruleAddresses), graphRulesData);
    }

    function removeFollowRules(
        address account,
        address[] calldata ruleAddresses,
        RuleExecutionData calldata graphRulesData
    ) external override {
        require(msg.sender == account || _hasAccess(SKIP_FOLLOW_RULES_CHECKS_RID));
        bytes32 followRuleKey = _getFollowRuleKeyByAccount(account);
        for (uint256 i = 0; i < ruleAddresses.length; i++) {
            // Passes the rule to add, and the call to do to configure the rule (account, configData)
            _removeRule(followRuleKey, ruleAddresses[i]);
            emit Lens_Graph_Follow_RuleRemoved(account, ruleAddresses[i]);
        }
        _processRules(IGraphRule.FOLLOW_RULES_CHANGE_SELECTOR, abi.encode(account, ruleAddresses), graphRulesData);
    }

    function follow(
        address followerAccount,
        address targetAccountToFollow,
        uint256 followId,
        RuleExecutionData calldata graphRulesData,
        RuleExecutionData calldata followRulesData
    ) public override returns (uint256) {
        require(msg.sender == followerAccount || _hasAccess(OVERRIDE_FOLLOW_RID));
        uint256 assignedFollowId = Core._follow(followerAccount, targetAccountToFollow, followId);

        _processRules(
            IGraphRule.FOLLOW_SELECTOR,
            abi.encode(msg.sender, followerAccount, targetAccountToFollow, assignedFollowId),
            graphRulesData
        );

        _processRules(
            _getFollowRuleKeyByAccount(targetAccountToFollow),
            IFollowRule.FOLLOW_SELECTOR,
            abi.encode(msg.sender, followerAccount, assignedFollowId),
            followRulesData
        );

        emit Lens_Graph_Followed(
            followerAccount, targetAccountToFollow, assignedFollowId, graphRulesData, followRulesData
        );
        return assignedFollowId;
    }

    function unfollow(
        address followerAccount,
        address targetAccountToUnfollow,
        RuleExecutionData calldata graphRulesData
    ) public override returns (uint256) {
        require(msg.sender == followerAccount || _hasAccess(OVERRIDE_FOLLOW_RID));
        uint256 followId = Core._unfollow(followerAccount, targetAccountToUnfollow);

        _processRules(
            IGraphRule.UNFOLLOW_SELECTOR,
            abi.encode(msg.sender, followerAccount, targetAccountToUnfollow, followId),
            graphRulesData
        );

        emit Lens_Graph_Unfollowed(followerAccount, targetAccountToUnfollow, followId, graphRulesData);
        return followId;
    }

    function setUserExtraData(address account, DataElement[] calldata extraDataToSet) external {
        require(msg.sender == account || _hasAccess(SKIP_FOLLOW_RULES_CHECKS_RID));
        _setEmbeddedExtraData(uint256(uint160(account)), extraDataToSet);
    }

    // Internal

    function _getFollowRuleKeyByAccount(address account) internal pure returns (bytes32) {
        return keccak256(abi.encode(FOLLOW_RULE_STORAGE_KEY, account));
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

    function getGraphRules(bool isRequired) external view override returns (address[] memory) {
        return _getRulesArray(isRequired);
    }

    function getFollowRules(address account, bool isRequired) external view override returns (IFollowRule) {
        return _getRulesArray(_getFollowRuleKeyByAccount(account), isRequired);
    }

    function getFollowersCount(address account) external view override returns (uint256) {
        return Core.$storage().followersCount[account];
    }
}
