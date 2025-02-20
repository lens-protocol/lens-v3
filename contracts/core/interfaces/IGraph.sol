// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {RuleProcessingParams, KeyValue, RuleChange, Rule} from "contracts/core/types/Types.sol";
import {IMetadataBased} from "contracts/core/interfaces/IMetadataBased.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";

struct Follow {
    uint256 id;
    uint256 timestamp;
}

interface IGraph is IMetadataBased {
    event Lens_Graph_RuleConfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Graph_RuleReconfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Graph_RuleSelectorEnabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_RuleSelectorDisabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_Follow_RuleConfigured(
        address indexed account, address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams
    );

    event Lens_Graph_Follow_RuleReconfigured(
        address indexed account, address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams
    );

    event Lens_Graph_Follow_RuleSelectorEnabled(
        address indexed account, address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_Follow_RuleSelectorDisabled(
        address indexed account, address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Graph_Followed(
        address indexed followerAccount,
        address indexed accountToFollow,
        uint256 followId,
        KeyValue[] customParams,
        RuleProcessingParams[] graphRulesProcessingParams,
        RuleProcessingParams[] followRulesProcessingParams,
        address indexed source,
        KeyValue[] extraData
    );

    event Lens_Graph_Unfollowed(
        address indexed followerAccount,
        address indexed accountToUnfollow,
        uint256 followId,
        KeyValue[] customParams,
        RuleProcessingParams[] graphRulesProcessingParams,
        address indexed source
    );

    event Lens_Graph_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Graph_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Graph_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Graph_MetadataURISet(string metadataURI);

    function initialize(string memory metadataURI, IAccessControl accessControl) external;

    function changeGraphRules(RuleChange[] calldata ruleChanges) external;

    function changeFollowRules(
        address account,
        RuleChange[] calldata ruleChanges,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external;

    function follow(
        address followerAccount,
        address accountToFollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams,
        RuleProcessingParams[] calldata followRulesProcessingParams,
        KeyValue[] calldata extraData
    ) external returns (uint256);

    function unfollow(
        address followerAccount,
        address accountToUnfollow,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata graphRulesProcessingParams
    ) external returns (uint256);

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    // Getters

    function isFollowing(address followerAccount, address targetAccount) external view returns (bool);

    function getFollowerById(address account, uint256 followId) external view returns (address);

    function getFollow(address followerAccount, address followedAccount) external view returns (Follow memory);

    function getFollowersCount(address account) external view returns (uint256);

    function getFollowingCount(address account) external view returns (uint256);

    function getGraphRules(bytes4 ruleSelector, bool isRequired) external view returns (Rule[] memory);

    function getFollowRules(address account, bytes4 ruleSelector, bool isRequired)
        external
        view
        returns (Rule[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);

    function getFollowSource(address followedAccount, uint256 followId) external view returns (address);
}
