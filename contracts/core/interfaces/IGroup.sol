// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue, RuleChange, RuleProcessingParams, SourceStamp} from "./../types/Types.sol";
import {IMetadataBased} from "./IMetadataBased.sol";

interface IGroup is IMetadataBased {
    event Lens_Group_RuleAdded(
        address indexed rule,
        bytes32 indexed configSalt,
        bytes4 indexed ruleSelector,
        KeyValue[] configParams,
        bool isRequired
    );

    event Lens_Group_RuleUpdated(
        address indexed rule,
        bytes32 indexed configSalt,
        bytes4 indexed ruleSelector,
        KeyValue[] configParams,
        bool isRequired
    );

    event Lens_Group_RuleRemoved(address indexed rule, bytes32 indexed configSalt, bytes4 indexed ruleSelector);

    event Lens_Group_MemberAdded(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams ruleProcessingParams,
        address source
    );

    event Lens_Group_MemberRemoved(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams ruleProcessingParams,
        address source
    );

    event Lens_Group_MemberJoined(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams ruleProcessingParams,
        address source
    );

    event Lens_Group_MemberLeft(
        address indexed account,
        uint256 indexed membershipId,
        KeyValue[] customParams,
        RuleProcessingParams ruleProcessingParams,
        address source
    );

    event Lens_Group_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Group_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Group_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Group_MetadataURISet(string metadataURI);

    function addMember(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external;

    function removeMember(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external;

    function joinGroup(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external;

    function leaveGroup(
        address account,
        KeyValue[] customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        SourceStamp calldata sourceStamp
    ) external;

    function changeGroupRules(RuleChange[] calldata ruleChanges) external;

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    function getNumberOfMembers() external view returns (uint256);

    function getMembershipTimestamp(address account) external view returns (uint256);

    function getMembershipId(address account) external view returns (uint256);

    function getGroupRules(bytes4 ruleSelector, bool isRequired) external view returns (Rule[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
