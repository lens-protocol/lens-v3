// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataElement, RuleConfiguration, RuleExecutionData} from "./../../types/Types.sol";
import {IMetadataBased} from "./../base/IMetadataBased.sol";

interface ICommunity is IMetadataBased {
    event Lens_Community_RuleAdded(address indexed rule, bytes configData, bool indexed isRequired);
    event Lens_Community_RuleUpdated(address indexed rule, bytes configData, bool indexed isRequired);
    event Lens_Community_RuleRemoved(address indexed rule);

    event Lens_Community_MemberJoined(address indexed account, uint256 indexed membershipId, RuleExecutionData data);
    event Lens_Community_MemberLeft(address indexed account, uint256 indexed membershipId, RuleExecutionData data);
    event Lens_Community_MemberRemoved(address indexed account, uint256 indexed membershipId, RuleExecutionData data);

    event Lens_Community_ExtraDataSet(bytes32 indexed key, bytes value, bytes indexed valueIndexed);

    event Lens_Community_MetadataURISet(string metadataURI);

    function addCommunityRules(RuleConfiguration[] calldata rules) external;

    function updateCommunityRules(RuleConfiguration[] calldata rules) external;

    function removeCommunityRules(address[] calldata rules) external;

    function setExtraData(DataElement[] calldata extraDataToSet) external;

    function joinCommunity(address account, RuleExecutionData calldata data) external;

    function leaveCommunity(address account, RuleExecutionData calldata data) external;

    function removeMember(address account, RuleExecutionData calldata data) external;

    function getNumberOfMembers() external view returns (uint256);

    function getMembershipTimestamp(address account) external view returns (uint256);

    function getMembershipId(address account) external view returns (uint256);

    function getCommunityRules(bool isRequired) external view returns (address[] memory);

    function getExtraData(bytes32 key) external view returns (bytes memory);
}
