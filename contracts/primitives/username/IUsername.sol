// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataElement, RuleConfiguration, RuleExecutionData, DataElementValue} from "../../types/Types.sol";
import {IMetadataBased} from "./../base/IMetadataBased.sol";

interface IUsername is IMetadataBased {
    event Lens_Username_RuleAdded(address indexed ruleAddress, bytes configData, bool indexed isRequired);

    event Lens_Username_RuleUpdated(address indexed ruleAddress, bytes configData, bool indexed isRequired);

    event Lens_Username_RuleRemoved(address indexed ruleAddress);

    event Lens_Username_Created(string username, address indexed account, RuleExecutionData data);

    event Lens_Username_Removed(string username, address indexed account, RuleExecutionData data);

    event Lens_Username_Assigned(string username, address indexed account, RuleExecutionData data);

    event Lens_Username_Unassigned(string username, address indexed previousAccount, RuleExecutionData data);

    event Lens_Username_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Username_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Username_ExtraDataRemoved(bytes32 indexed key);

    event Lens_Username_MetadataURISet(address indexed source, string metadataURI);

    function setExtraData(DataElement[] calldata extraDataToSet) external;

    function removeExtraData(bytes32[] calldata extraDataKeysToRemove) external;

    function addUsernameRules(RuleConfiguration[] calldata ruleConfigurations) external;

    function updateUsernameRules(RuleConfiguration[] calldata ruleConfigurations) external;

    function removeUsernameRules(address[] calldata rules) external;

    function createUsername(address account, string memory username, RuleExecutionData calldata data) external;

    function removeUsername(string memory username, RuleExecutionData calldata data) external;

    function assignUsername(address account, string memory username, RuleExecutionData calldata data) external;

    function unassignUsername(string memory username, RuleExecutionData calldata data) external;

    function usernameOf(address user) external view returns (string memory);

    function accountOf(string memory name) external view returns (address);

    function getNamespace() external view returns (string memory);

    function getUsernameRules(bool isRequired) external view returns (address[] memory);

    function getExtraData(bytes32 key) external view returns (DataElementValue memory);
}
