// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {KeyValue, RuleChange, RuleExecutionData, SourceStamp} from "./../types/Types.sol";
import {IMetadataBased} from "./IMetadataBased.sol";

interface IUsername is IMetadataBased {
    event Lens_Username_RuleAdded(address indexed ruleAddress, bytes configData, bool indexed isRequired);

    event Lens_Username_RuleUpdated(address indexed ruleAddress, bytes configData, bool indexed isRequired);

    event Lens_Username_RuleRemoved(address indexed ruleAddress);

    event Lens_Username_Created(string username, address indexed account, RuleExecutionData data, address source);

    event Lens_Username_Removed(string username, address indexed account, address source);

    event Lens_Username_Assigned(string username, address indexed account, RuleExecutionData data, address source);

    event Lens_Username_Unassigned(string username, address indexed previousAccount, address source);

    event Lens_Username_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Username_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Username_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Username_MetadataURISet(string metadataURI);

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    function changeUsernameRules(RuleChange[] calldata ruleChanges) external;

    function createUsername(
        address account,
        string memory username,
        RuleExecutionData calldata data,
        SourceStamp calldata sourceStamp
    ) external;

    function removeUsername(string memory username, SourceStamp calldata sourceStamp) external;

    function assignUsername(
        address account,
        string memory username,
        RuleExecutionData calldata data,
        SourceStamp calldata sourceStamp
    ) external;

    function unassignUsername(string memory username, SourceStamp calldata sourceStamp) external;

    function usernameOf(address user) external view returns (string memory);

    function accountOf(string memory name) external view returns (address);

    function getNamespace() external view returns (string memory);

    function getUsernameRules(bool isRequired) external view returns (address[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
