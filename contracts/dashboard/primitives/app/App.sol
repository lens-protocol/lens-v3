// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IAccessControl} from "./../../../core/interfaces/IAccessControl.sol";
import {IApp} from "./IApp.sol";
import {AppCore as Core} from "./AppCore.sol";
import {KeyValue, SourceStamp} from "./../../../core/types/Types.sol";
import {AccessControlled} from "./../../../core/access/AccessControlled.sol";
import {Events} from "./../../../core/types/Events.sol";
import {BaseSource} from "./../../../core/base/BaseSource.sol";
import {ISource} from "./../../../core/interfaces/ISource.sol";

struct AppInitialProperties {
    address graph;
    address[] feeds;
    address username;
    address[] groups;
    address defaultFeed;
    address[] signers;
    address paymaster;
    address treasury;
}

contract App is IApp, BaseSource, AccessControlled {
    // Resource IDs involved in the contract

    uint256 constant SET_PRIMITIVES_PID = uint256(keccak256("SET_PRIMITIVES"));
    uint256 constant SET_SIGNERS_PID = uint256(keccak256("SET_SIGNERS"));
    uint256 constant SET_TREASURY_PID = uint256(keccak256("SET_TREASURY"));
    uint256 constant SET_PAYMASTER_PID = uint256(keccak256("SET_PAYMASTER"));
    uint256 constant SET_EXTRA_DATA_PID = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant SET_METADATA_PID = uint256(keccak256("SET_METADATA"));
    uint256 constant SET_SOURCE_STAMP_VERIFICATION_PID = uint256(keccak256("SET_SOURCE_STAMP_VERIFICATION"));

    constructor(
        string memory metadataURI,
        bool isSourceStampVerificationEnabled,
        IAccessControl accessControl,
        AppInitialProperties memory initialProps,
        KeyValue[] memory extraData
    ) AccessControlled(accessControl) {
        _setMetadataURI(metadataURI);
        _setSourceStampVerification(isSourceStampVerificationEnabled);
        _setTreasury(initialProps.treasury);
        _setGraph(initialProps.graph);
        _addFeeds(initialProps.feeds);
        _setUsername(initialProps.username);
        _addGroups(initialProps.groups);
        _setDefaultFeed(initialProps.defaultFeed);
        _addSigners(initialProps.signers);
        _setPaymaster(initialProps.paymaster);
        _setExtraData(extraData);

        _emitPIDs();

        emit Events.Lens_Contract_Deployed("app", "lens.app", "app", "lens.app");
    }

    function _emitPIDs() internal override {
        super._emitPIDs();
        emit Events.Lens_PermissionId_Available(SET_PRIMITIVES_PID, "SET_PRIMITIVES");
        emit Events.Lens_PermissionId_Available(SET_SIGNERS_PID, "SET_SIGNERS");
        emit Events.Lens_PermissionId_Available(SET_TREASURY_PID, "SET_TREASURY");
        emit Events.Lens_PermissionId_Available(SET_PAYMASTER_PID, "SET_PAYMASTER");
        emit Events.Lens_PermissionId_Available(SET_EXTRA_DATA_PID, "SET_EXTRA_DATA");
        emit Events.Lens_PermissionId_Available(SET_METADATA_PID, "SET_METADATA");
        emit Events.Lens_PermissionId_Available(SET_SOURCE_STAMP_VERIFICATION_PID, "SET_SOURCE_STAMP_VERIFICATION");
    }

    function _validateSource(SourceStamp calldata sourceStamp) internal virtual override {
        // If source stamp verification is disabled, we don't need to verify the source stamp
        if (!Core.$storage().sourceStampVerificationEnabled) {
            super._validateSource(sourceStamp);
        }
    }

    function _isValidSourceStampSigner(address signer) internal virtual override returns (bool) {
        return Core.$storage().signerStorageHelper[signer].isSet; // TODO: What about the app's owner?
    }

    function _setSourceStampVerification(bool isEnabled) internal virtual {
        Core.$storage().sourceStampVerificationEnabled = isEnabled;
        emit Lens_App_SourceStampVerificationSet(isEnabled);
    }

    function setSourceStampVerification(bool isEnabled) external virtual override {
        _requireAccess(msg.sender, SET_SOURCE_STAMP_VERIFICATION_PID);
        _setSourceStampVerification(isEnabled);
    }

    ///////////////// Graph

    function setGraph(address graph) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _setGraph(graph);
    }

    // In this implementation we allow to have a single graph only.
    function _setGraph(address graph) internal {
        address graphPreviouslySet = Core.$storage().defaultGraph;
        if (graphPreviouslySet != address(0)) {
            Core._removeGraph(graphPreviouslySet);
            emit Lens_App_GraphRemoved(graphPreviouslySet);
        }
        if (graph != address(0)) {
            emit Lens_App_GraphAdded(graph);
            Core._addGraph(graph);
        }
        Core._setDefaultGraph(graph);
    }

    ///////////////// Feed

    function addFeeds(address[] memory feeds) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _addFeeds(feeds);
    }

    function removeFeeds(address[] memory feeds) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _removeFeeds(feeds);
    }

    function setDefaultFeed(address feed) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _setDefaultFeed(feed);
    }

    function _addFeeds(address[] memory feeds) internal {
        for (uint256 i = 0; i < feeds.length; i++) {
            Core._addFeed(feeds[i]);
            emit Lens_App_FeedAdded(feeds[i]);
        }
    }

    function _removeFeeds(address[] memory feeds) internal {
        address defaultFeed = Core.$storage().defaultFeed;
        for (uint256 i = 0; i < feeds.length; i++) {
            if (feeds[i] == defaultFeed) {
                _setDefaultFeed(address(0));
            }
            Core._removeFeed(feeds[i]);
            emit Lens_App_FeedRemoved(feeds[i]);
        }
    }

    function _setDefaultFeed(address feed) internal {
        Core._setDefaultFeed(feed);
        emit Lens_App_DefaultFeedSet(feed);
    }

    ///////////////// Username

    function setUsername(address username) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _setUsername(username);
    }

    // In this implementation we allow to have a single graph only.
    function _setUsername(address username) internal {
        address usernamePreviouslySet = Core.$storage().defaultUsername;
        if (usernamePreviouslySet != address(0)) {
            Core._removeUsername(usernamePreviouslySet);
            emit Lens_App_UsernameRemoved(usernamePreviouslySet);
        }
        if (username != address(0)) {
            emit Lens_App_UsernameAdded(username);
            Core._addUsername(username);
        }
        Core._setDefaultUsername(username);
    }

    ///////////////// Group

    function addGroups(address[] memory groups) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _addGroups(groups);
    }

    function removeGroups(address[] memory groups) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _removeGroups(groups);
    }

    function _addGroups(address[] memory groups) internal {
        for (uint256 i = 0; i < groups.length; i++) {
            Core._addGroup(groups[i]);
            emit Lens_App_GroupAdded(groups[i]);
        }
    }

    function _removeGroups(address[] memory groups) internal {
        for (uint256 i = 0; i < groups.length; i++) {
            Core._removeGroup(groups[i]);
            emit Lens_App_GroupRemoved(groups[i]);
        }
    }

    ///////////////// Signers

    function addSigners(address[] memory signers) external {
        _requireAccess(msg.sender, SET_SIGNERS_PID);
        _addSigners(signers);
    }

    function removeSigners(address[] memory signers) external {
        _requireAccess(msg.sender, SET_SIGNERS_PID);
        _removeSigners(signers);
    }

    function _addSigners(address[] memory signers) internal {
        for (uint256 i = 0; i < signers.length; i++) {
            Core._addSigner(signers[i]);
            emit Lens_App_SignerAdded(signers[i]);
        }
    }

    function _removeSigners(address[] memory signers) internal {
        for (uint256 i = 0; i < signers.length; i++) {
            Core._removeSigner(signers[i]);
            emit Lens_App_SignerRemoved(signers[i]);
        }
    }

    ///////////////// Paymaster

    function setPaymaster(address paymaster) external override {
        _requireAccess(msg.sender, SET_PRIMITIVES_PID);
        _setPaymaster(paymaster);
    }

    // In this implementation we allow to have a single paymaster only.
    function _setPaymaster(address paymaster) internal {
        address paymasterPreviouslySet = Core.$storage().defaultPaymaster;
        if (paymasterPreviouslySet != address(0)) {
            Core._removePaymaster(paymasterPreviouslySet);
            emit Lens_App_PaymasterRemoved(paymasterPreviouslySet);
        }
        if (paymaster != address(0)) {
            emit Lens_App_PaymasterAdded(paymaster);
            Core._addPaymaster(paymaster);
        }
        Core._setDefaultPaymaster(paymaster);
    }

    function getPaymaster() external view override returns (address) {
        return Core.$storage().defaultPaymaster;
    }

    ///////////////// Treasury

    function setTreasury(address treasury) external override {
        _requireAccess(msg.sender, SET_TREASURY_PID);
        _setTreasury(treasury);
    }

    function _setTreasury(address treasury) internal {
        Core._setTreasury(treasury);
        emit Lens_App_TreasurySet(treasury);
    }

    function getTreasury() external view override(IApp, ISource) returns (address) {
        return Core.$storage().treasury;
    }

    ///////////////// Metadata URI

    function setMetadataURI(string calldata metadataURI) external override {
        _requireAccess(msg.sender, SET_METADATA_PID);
        _setMetadataURI(metadataURI);
    }

    function _setMetadataURI(string memory metadataURI) internal {
        Core._setMetadataURI(metadataURI);
        emit Lens_App_MetadataURISet(metadataURI);
    }

    ///////////////// Extra Data

    function setExtraData(KeyValue[] calldata extraDataToSet) external override {
        _requireAccess(msg.sender, SET_EXTRA_DATA_PID);
        _setExtraData(extraDataToSet);
    }

    function _setExtraData(KeyValue[] memory extraDataToSet) internal {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            bool hadAValueSetBefore = Core._setExtraData(extraDataToSet[i]);
            bool isNewValueEmpty = extraDataToSet[i].value.length == 0;
            if (hadAValueSetBefore) {
                if (isNewValueEmpty) {
                    emit Lens_App_ExtraDataRemoved(extraDataToSet[i].key);
                } else {
                    emit Lens_App_ExtraDataUpdated(
                        extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value
                    );
                }
            } else if (!isNewValueEmpty) {
                emit Lens_App_ExtraDataAdded(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
            }
        }
    }

    //////////////////////////////////////////////////////////////////////////
    // Getters
    //////////////////////////////////////////////////////////////////////////

    function getGraphs() external view override returns (address[] memory) {
        return Core.$storage().graphs;
    }

    function getFeeds() external view override returns (address[] memory) {
        return Core.$storage().feeds;
    }

    function getUsernames() external view override returns (address[] memory) {
        return Core.$storage().usernames;
    }

    function getGroups() external view override returns (address[] memory) {
        return Core.$storage().groups;
    }

    function getDefaultGraph() external view override returns (address) {
        return Core.$storage().defaultGraph;
    }

    function getDefaultFeed() external view override returns (address) {
        return Core.$storage().defaultFeed;
    }

    function getDefaultUsername() external view override returns (address) {
        return Core.$storage().defaultUsername;
    }

    function getDefaultGroup() external view override returns (address) {
        return Core.$storage().defaultGroup;
    }

    function getDefaultPaymaster() external view override returns (address) {
        return Core.$storage().defaultPaymaster;
    }

    function getSigners() external view override returns (address[] memory) {
        return Core.$storage().signers;
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().extraData[key];
    }

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }
}
