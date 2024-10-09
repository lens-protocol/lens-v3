// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataElement, RuleConfiguration, RuleExecutionData} from "../../types/Types.sol";
import {IMetadataBased} from "./../base/IMetadataBased.sol";

interface IUsername is IMetadataBased {
    event Lens_Username_RuleAdded(address indexed ruleAddress, bytes configData, bool indexed isRequired);

    event Lens_Username_RuleUpdated(address indexed ruleAddress, bytes configData, bool indexed isRequired);

    event Lens_Username_RuleRemoved(address indexed ruleAddress);

    event Lens_Username_Registered(string username, address indexed account, RuleExecutionData data);

    event Lens_Username_Unregistered(string username, address indexed previousAccount, RuleExecutionData data);

    event Lens_Username_ExtraDataSet(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Username_MetadataURISet(string metadataURI);

    function setExtraData(DataElement[] calldata extraDataToSet) external;

    function addUsernameRules(RuleConfiguration[] calldata ruleConfigurations) external;

    function updateUsernameRules(RuleConfiguration[] calldata ruleConfigurations) external;

    function removeUsernameRules(address[] calldata rules) external;

    function registerUsername(address account, string memory username, RuleExecutionData calldata data) external;

    function unregisterUsername(string memory username, RuleExecutionData calldata data) external;

    function usernameOf(address user) external view returns (string memory);

    function accountOf(string memory name) external view returns (address);

    function getNamespace() external view returns (string memory);

    function getUsernameRules(bool isRequired) external view returns (address[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
