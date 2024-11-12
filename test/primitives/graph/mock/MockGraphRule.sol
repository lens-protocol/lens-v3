// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IGraphRule} from "../../../../contracts/primitives/graph/IGraphRule.sol";
import {RuleConfiguration} from "../../../../contracts/types/Types.sol";

contract MockGraphRule is IGraphRule {
    string public lastConfig;
    address public lastFollowerAccount;
    address public lastAccountToFollow;
    uint256 public lastFollowId;
    address public lastUnfollowerAccount;
    address public lastAccountToUnfollow;
    address public lastAccountRulesChanged;
    RuleConfiguration[] public lastFollowRules;
    mapping(address => bool) public whitelistedRules;
    bool public configurationWillFail = false;
    bool public requireWhitelisted = false;
    bool public allowRuleChanges = true;
    bool public shouldPass = true;

    function configure(bytes calldata data) external override {
        require(!configurationWillFail, "Configuration failed");
        lastConfig = abi.decode(data, (string));
    }

    function processFollow(address followerAccount, address accountToFollow, uint256 followId, bytes calldata)
        external
        override
    {
        require(shouldPass, "ProcessFollow failed");
        lastFollowerAccount = followerAccount;
        lastAccountToFollow = accountToFollow;
        lastFollowId = followId;
    }

    function processUnfollow(address unfollowerAccount, address accountToUnfollow, uint256 followId, bytes calldata)
        external
        override
    {
        require(shouldPass, "ProcessUnfollow failed");
        lastUnfollowerAccount = unfollowerAccount;
        lastAccountToUnfollow = accountToUnfollow;
        lastFollowId = followId;
    }

    function processFollowRulesChange(address account, RuleConfiguration[] calldata followRules, bytes calldata)
        external
        override
    {
        require(allowRuleChanges, "Rule changes not allowed");
        if (requireWhitelisted) {
            for (uint256 i = 0; i < followRules.length; i++) {
                require(whitelistedRules[followRules[i].ruleAddress], "Rule not whitelisted");
            }
        }
    }

    function setConfigurationWillFail(bool willFail) external {
        configurationWillFail = willFail;
    }

    function setWhitelistedRule(address rule, bool isWhitelisted) external {
        whitelistedRules[rule] = isWhitelisted;
    }

    function setRequireWhitelisted(bool whitelist) external {
        requireWhitelisted = whitelist;
    }

    function setAllowRuleChanges(bool allow) external {
        allowRuleChanges = allow;
    }

    function setShouldPass(bool _shouldPass) external {
        shouldPass = _shouldPass;
    }
}
