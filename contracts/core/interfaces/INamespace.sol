// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {KeyValue, RuleChange, RuleProcessingParams, Rule} from "contracts/core/types/Types.sol";
import {IMetadataBased} from "contracts/core/interfaces/IMetadataBased.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";

interface INamespace is IMetadataBased {
    event Lens_Namespace_RuleConfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Namespace_RuleReconfigured(address indexed rule, bytes32 indexed configSalt, KeyValue[] configParams);

    event Lens_Namespace_RuleSelectorEnabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Namespace_RuleSelectorDisabled(
        address indexed rule, bytes32 indexed configSalt, bool isRequired, bytes4 ruleSelector
    );

    event Lens_Username_Created(
        string username,
        address indexed account,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source,
        KeyValue[] extraData
    );

    event Lens_Username_Removed(
        string username,
        address indexed account,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    event Lens_Username_Assigned(
        string username,
        address indexed account,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    event Lens_Username_Unassigned(
        string username,
        address indexed previousAccount,
        KeyValue[] customParams,
        RuleProcessingParams[] ruleProcessingParams,
        address indexed source
    );

    event Lens_Namespace_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Namespace_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_Namespace_ExtraDataRemoved(bytes32 indexed key);
    event Lens_Username_ExtraDataAdded(
        uint256 indexed usernameId, bytes32 indexed key, bytes value, bytes indexed valueIndexed
    );
    event Lens_Username_ExtraDataUpdated(
        uint256 indexed usernameId, bytes32 indexed key, bytes value, bytes indexed valueIndexed
    );
    event Lens_Username_ExtraDataRemoved(uint256 indexed usernameId, bytes32 indexed key);

    event Lens_Namespace_MetadataURISet(string metadataURI);

    function initialize(
        string memory namespace,
        string memory metadataURI,
        string memory nftName,
        string memory nftSymbol,
        ITokenURIProvider tokenURIProvider,
        IAccessControl accessControl
    ) external;

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    function changeNamespaceRules(RuleChange[] calldata ruleChanges) external;

    function createUsername(
        address account,
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams,
        KeyValue[] calldata extraData
    ) external;

    function removeUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassigningRuleProcessingParams,
        RuleProcessingParams[] calldata removalRuleProcessingParams
    ) external;

    function assignUsername(
        address account,
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata unassignAccountRuleProcessingParams,
        RuleProcessingParams[] calldata unassignUsernameRuleProcessingParams,
        RuleProcessingParams[] calldata assignRuleProcessingParams
    ) external;

    function unassignUsername(
        string calldata username,
        KeyValue[] calldata customParams,
        RuleProcessingParams[] calldata ruleProcessingParams
    ) external;

    function setUsernameExtraData(string memory username, KeyValue[] calldata extraDataToSet) external;

    function usernameOf(address user) external view returns (string memory);

    function accountOf(string calldata name) external view returns (address);

    function ownerOf(string memory username) external view returns (address);

    function getNamespace() external view returns (string memory);

    function getNamespaceRules(bytes4 ruleSelector, bool isRequired) external view returns (Rule[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);

    function getUsernameExtraData(string calldata username, bytes32 key) external view returns (bytes memory);

    function exists(string calldata username) external view returns (bool);

    function getUsernameCreationSource(string calldata username) external view returns (address);

    function getUsernameAssignmentSource(string calldata username) external view returns (address);
}
