// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RuleConfiguration, RuleExecutionData, DataElement} from "./../../types/Types.sol";
import {IMetadataBased} from "./../base/IMetadataBased.sol";

// TODO: Might worth to add extraData to the follow entity
// Maybe it requires a targetExtraData and a followerExtraData
// so then you have different auth for them, and they store different data
// e.g. the follower can store a label/tag/category, like "I follow this account because of crypto/politics/etc"
// and the target can store other information like tiers, etc.
struct Follow {
    uint256 id;
    uint256 timestamp;
}

interface IGraph is IMetadataBased {
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
        RuleExecutionData graphRulesData,
        RuleExecutionData followRulesData
    );

    event Lens_Graph_Unfollowed(
        address indexed followerAccount,
        address indexed accountToUnfollow,
        uint256 followId,
        RuleExecutionData graphRulesData
    );

    event Lens_Graph_ExtraDataSet(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Graph_MetadataURISet(string metadataURI);

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

    function setExtraData(DataElement[] calldata extraDataToSet) external;

    // Getters

    function isFollowing(address followerAccount, address targetAccount) external view returns (bool);

    function getFollowerById(address account, uint256 followId) external view returns (address);

    function getFollow(address followerAccount, address followedAccount) external view returns (Follow memory);

    function getFollowersCount(address account) external view returns (uint256);

    function getGraphRules(bool isRequired) external view returns (address[] memory);

    function getFollowRules(address account, bool isRequired) external view returns (address[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
