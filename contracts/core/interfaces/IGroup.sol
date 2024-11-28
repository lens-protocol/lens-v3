// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {DataElement, RuleChange, RuleExecutionData} from "./../types/Types.sol";
import {IMetadataBased} from "./IMetadataBased.sol";
import {SourceStamp} from "./../types/Types.sol";

interface IGroup is IMetadataBased {
    event Lens_Group_RuleAdded(address indexed rule, bytes configData, bool indexed isRequired);
    event Lens_Group_RuleUpdated(address indexed rule, bytes configData, bool indexed isRequired);
    event Lens_Group_RuleRemoved(address indexed rule);

    event Lens_Group_MemberJoined(
        address indexed account, uint256 indexed membershipId, RuleExecutionData data, address source
    );
    event Lens_Group_MemberLeft(
        address indexed account, uint256 indexed membershipId, RuleExecutionData data, address source
    );
    event Lens_Group_MemberRemoved(
        address indexed account, uint256 indexed membershipId, RuleExecutionData data, address source
    );

    event Lens_Group_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Group_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Group_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Group_MetadataURISet(string metadataURI);

    function changeGroupRules(RuleChange[] calldata ruleChanges) external;

    function setExtraData(DataElement[] calldata extraDataToSet) external;

    function joinGroup(address account, RuleExecutionData calldata data, SourceStamp calldata sourceStamp) external;

    function leaveGroup(address account, RuleExecutionData calldata data, SourceStamp calldata sourceStamp) external;

    function removeMember(address account, RuleExecutionData calldata data, SourceStamp calldata sourceStamp) external;

    function getNumberOfMembers() external view returns (uint256);

    function getMembershipTimestamp(address account) external view returns (uint256);

    function getMembershipId(address account) external view returns (uint256);

    function getGroupRules(bool isRequired) external view returns (address[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
