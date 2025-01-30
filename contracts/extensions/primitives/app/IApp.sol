// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IMetadataBased} from "contracts/core/interfaces/IMetadataBased.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {AppInitialProperties} from "contracts/extensions/primitives/app/App.sol";

interface IApp is IMetadataBased {
    // Graph
    event Lens_App_GraphAdded(address indexed graph);
    event Lens_App_GraphRemoved(address indexed graph);

    // Feed
    event Lens_App_FeedAdded(address indexed feed);
    event Lens_App_FeedRemoved(address indexed feed);
    event Lens_App_DefaultFeedSet(address indexed feed);

    // Namespace
    event Lens_App_NamespaceAdded(address indexed namespace);
    event Lens_App_NamespaceRemoved(address indexed namespace);

    // Group
    event Lens_App_GroupAdded(address indexed group);
    event Lens_App_GroupRemoved(address indexed group);
    event Lens_App_DefaultGroupSet(address indexed group);

    // Paymaster
    event Lens_App_PaymasterAdded(address indexed paymaster);
    event Lens_App_PaymasterRemoved(address indexed paymaster);

    // Signer
    event Lens_App_SignerAdded(address indexed signer);
    event Lens_App_SignerRemoved(address indexed signer);

    // Extra Data
    event Lens_App_ExtraDataAdded(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_App_ExtraDataUpdated(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_App_ExtraDataRemoved(bytes32 indexed key);

    // Metadata URI
    event Lens_App_MetadataURISet(string metadataURI);

    // Treasury
    event Lens_App_TreasurySet(address indexed treasury);

    // Source Stamp Verification
    event Lens_App_SourceStampVerificationSet(bool indexed isEnabled);

    function initialize(
        string memory metadataURI,
        bool isSourceStampVerificationEnabled,
        IAccessControl accessControl,
        AppInitialProperties memory initialProps,
        KeyValue[] memory extraData
    ) external;

    // Setters

    function addGroups(address[] memory groups) external;
    function removeGroups(address[] memory groups) external;
    function setDefaultGroup(address group) external;

    function addFeeds(address[] memory feeds) external;
    function removeFeeds(address[] memory feeds) external;
    function setDefaultFeed(address feed) external;

    function setGraph(address graph) external;

    function setNamespace(address namespace) external;

    function addSigners(address[] memory signers) external;
    function removeSigners(address[] memory signers) external;

    function setPaymaster(address paymaster) external;

    function setTreasury(address treasury) external;

    function setExtraData(KeyValue[] calldata extraDataToSet) external;

    function setSourceStampVerification(bool isEnabled) external;

    // Getters

    function getGroups() external view returns (address[] memory);

    function getFeeds() external view returns (address[] memory);

    function getGraphs() external view returns (address[] memory);

    function getNamespaces() external view returns (address[] memory);

    function getSigners() external view returns (address[] memory);

    function getPaymaster() external view returns (address);

    function getTreasury() external view returns (address);

    function getExtraData(bytes32 key) external view returns (bytes memory);

    function getDefaultGraph() external view returns (address);
    function getDefaultFeed() external view returns (address);
    function getDefaultNamespace() external view returns (address);
    function getDefaultGroup() external view returns (address);
    function getDefaultPaymaster() external view returns (address);
}
