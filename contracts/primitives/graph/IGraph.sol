// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IFollowRule} from "./IFollowRule.sol";
import {IGraphRule} from "./IGraphRule.sol";
import {RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";

struct Follow {
    uint256 id;
    uint256 timestamp;
}

interface IGraph {
    event Lens_Graph_MetadataUriSet(string metadataURI);

    event Lens_Graph_RuleAdded(address indexed ruleAddress, bytes configData, bool indexed isRequired);
    event Lens_Graph_RuleUpdated(address indexed ruleAddress, bytes configData, bool indexed isRequired);
    event Lens_Graph_RuleRemoved(address indexed ruleAddress);

    event Lens_Graph_Follow_RuleAdded(
        address indexed account, address indexed ruleAddress, RuleConfiguration ruleConfiguration
    );

    event Lens_Graph_Follow_RuleUpdated(
        address indexed account, address indexed ruleAddress, RuleConfiguration ruleConfiguration
    );

    event Lens_Graph_Follow_RuleRemoved(address indexed account, address indexed ruleAddress);

    event Lens_Graph_Followed(
        address indexed followerAccount,
        address indexed accountToFollow,
        uint256 followId,
        bytes graphRulesData,
        bytes followRulesData
    );

    event Lens_Graph_Unfollowed(
        address indexed followerAccount, address indexed accountToUnfollow, uint256 followId, bytes graphRulesData
    );

    function addGraphRules(RuleConfiguration[] calldata rules) external;

    function updateGraphRules(RuleConfiguration[] calldata rules) external;

    function removeGraphRules(address[] calldata rules) external;

    function addFollowRules(
        address account,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata graphRulesData
    ) external;
    function updateFollowRules(
        address account,
        RuleConfiguration[] calldata rules,
        RuleExecutionData calldata graphRulesData
    ) external;
    function removeFollowRules(address account, address[] calldata rules, RuleExecutionData calldata graphRulesData)
        external;

    function follow(
        address followerAccount,
        address targetAccount,
        uint256 followId,
        RuleExecutionData calldata graphRulesData,
        RuleExecutionData calldata followRulesData
    ) external returns (uint256);

    function unfollow(address followerAccount, address targetAccount, RuleExecutionData calldata graphRulesData)
        external
        returns (uint256);

    function setMetadataUri(string calldata metadataURI) external;

    // Getters

    function isFollowing(address followerAccount, address targetAccount) external view returns (bool);

    function getFollowerById(address account, uint256 followId) external view returns (address);

    function getFollow(address followerAccount, address followedAccount) external view returns (Follow memory);

    function getFollowersCount(address account) external view returns (uint256);

    function getFollowRules(address account, bool isRequired) external view returns (IFollowRule);

    function getGraphRules(bool isRequired) external view returns (address[] memory);
}
