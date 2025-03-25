// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue, RuleChange, RuleProcessingParams, Rule} from "contracts/core/types/Types.sol";
import {IMetadataBased} from "contracts/core/interfaces/IMetadataBased.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";

struct Membership {
    uint256 id;
    uint256 timestamp;
}

interface IGroup is IMetadataBased {
    event Lens_Group_RuleConfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Group_RuleReconfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Group_RuleSelectorEnabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Group_RuleSelectorDisabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Group_MemberAdded(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    event Lens_Group_MemberRemoved(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    event Lens_Group_MemberJoined(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    event Lens_Group_MemberLeft(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    event Lens_Group_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Group_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Group_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Group_MetadataURISet(string metadataURI);

    function initialize(string memory metadataURI, IAccessControl accessControl, address foundingMember) external;

    function addMember(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external;

    function removeMember(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external;

    function joinGroup(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external;

    function leaveGroup(
        address account,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external;

    function changeGroupRules(RuleChange[] calldata ruleChanges) external;

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    function getNumberOfMembers() external view returns (uint256);

    function isMember(address account) external view returns (bool);

    function getMembership(address account) external view returns (Membership memory);

    function getMembershipTimestamp(address account) external view returns (uint256);

    function getMembershipId(address account) external view returns (uint256);

    function getGroupRules(bytes4 ruleSelector, bool isRequired) external view returns (Rule[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);

    function getMembershipSource(uint256 membershipId) external view returns (address);
}
