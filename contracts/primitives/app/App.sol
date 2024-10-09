// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./../access-control/IAccessControl.sol";
import {IApp} from "./IApp.sol";
import {AppCore as Core} from "./AppCore.sol";
import {DataElement} from "./../../types/Types.sol";
import {AccessControlled} from "./../base/AccessControlled.sol";
import {Events} from "./../../types/Events.sol";

struct AppInitialProperties {
    address graph;
    address[] feeds;
    address username;
    address[] communities;
    address defaultFeed;
    address defaultCommunity;
    address[] signers;
    address paymaster;
    address treasury;
}

contract App is IApp, AccessControlled {
    // Resource IDs involved in the contract
    uint256 constant SET_PRIMITIVES = uint256(keccak256("SET_PRIMITIVES"));
    uint256 constant SET_SIGNERS = uint256(keccak256("SET_SIGNERS"));
    uint256 constant SET_TREASURY = uint256(keccak256("SET_TREASURY"));
    uint256 constant SET_PAYMASTER = uint256(keccak256("SET_PAYMASTER"));
    uint256 constant SET_EXTRA_DATA = uint256(keccak256("SET_EXTRA_DATA"));
    uint256 constant SET_METADATA = uint256(keccak256("SET_METADATA"));

    constructor(
        string memory metadataURI,
        IAccessControl accessControl,
        AppInitialProperties memory initialProps,
        DataElement[] memory extraData
    ) AccessControlled(accessControl) {
        _setMetadataURI(metadataURI);
        _setTreasury(initialProps.treasury);
        _setGraph(initialProps.graph);
        _setFeeds(initialProps.feeds);
        _setUsername(initialProps.username);
        _setCommunity(initialProps.communities);
        _setDefaultFeed(initialProps.defaultFeed);
        _setDefaultCommunity(initialProps.defaultCommunity);
        _setSigners(initialProps.signers);
        _setPaymaster(initialProps.paymaster);
        _setExtraData(extraData);

        _emitRIDs();

        emit Events.Lens_Contract_Deployed("app", "lens.app", "app", "lens.app");
    }

    function _emitRIDs() internal override {
        super._emitRIDs();
        emit Lens_ResourceId_Available(SET_PRIMITIVES, "SET_PRIMITIVES");
        emit Lens_ResourceId_Available(SET_SIGNERS, "SET_SIGNERS");
        emit Lens_ResourceId_Available(SET_TREASURY, "SET_TREASURY");
        emit Lens_ResourceId_Available(SET_PAYMASTER, "SET_PAYMASTER");
        emit Lens_ResourceId_Available(SET_EXTRA_DATA, "SET_EXTRA_DATA");
        emit Lens_ResourceId_Available(SET_METADATA, "SET_METADATA");
    }

    // TODO:
    // In this implementation we assume you can only have one graph.

    function setGraph(address graph) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        _setGraph(graph);
    }

    function _setGraph(address graph) internal {
        Core._setGraph(graph);
        emit Lens_App_GraphAdded(graph);
        emit Lens_App_DefaultGraphSet(graph);
    }

    // function setDefaultGraph(address graph) public {
    //     _requireAccess(msg.sender, SET_PRIMITIVES);
    //     Core._setDefaultGraph(graph);
    // }

    function setFeeds(address[] calldata feeds) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        _setFeeds(feeds);
    }

    function _setFeeds(address[] memory feeds) internal {
        address defaultFeedSet = Core._setFeeds(feeds);
        emit Lens_App_DefaultFeedSet(defaultFeedSet);
        emit Lens_App_FeedsSet(feeds);
    }

    function setDefaultFeed(address feed) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        _setDefaultFeed(feed);
    }

    function _setDefaultFeed(address feed) internal {
        Core._setDefaultFeed(feed);
        emit Lens_App_DefaultFeedSet(feed);
    }

    function addFeed(address feed) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        // TODO: Add check for duplicate, or use a mapping.
        Core._addFeed(feed);
        emit Lens_App_FeedAdded(feed);
    }

    function removeFeed(address feed, uint256 index) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        Core._removeFeed(feed, index);
        emit Lens_App_FeedRemoved(feed);
    }

    // TODO:
    // In this implementation we assume you can only have one username.

    function setUsername(address username) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        _setUsername(username);
    }

    function _setUsername(address username) internal {
        Core._setUsername(username);
        emit Lens_App_UsernameAdded(username);
        emit Lens_App_DefaultUsernameSet(username);
    }

    // function setDefaultUsername(address username) public {
    //     _requireAccess(msg.sender, SET_PRIMITIVES);
    //     Core._setDefaultUsername(username);
    // }

    function setCommunity(address[] calldata communities) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        _setCommunity(communities);
    }

    function _setCommunity(address[] memory communities) internal {
        address defaultCommunitySet = Core._setCommunity(communities);
        emit Lens_App_DefaultCommunitySet(defaultCommunitySet);
        emit Lens_App_CommunitiesSet(communities);
    }

    function setDefaultCommunity(address community) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        _setDefaultCommunity(community);
    }

    function _setDefaultCommunity(address community) internal {
        Core._setDefaultCommunity(community);
        emit Lens_App_DefaultCommunitySet(community);
    }

    function addCommunity(address community) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        // TODO: Add check for duplicate, or use a mapping.
        Core._addCommunity(community);
        emit Lens_App_CommunityAdded(community);
    }

    function removeCommunity(address community, uint256 index) public {
        _requireAccess(msg.sender, SET_PRIMITIVES);
        Core._removeCommunity(community, index);
        emit Lens_App_CommunityRemoved(community);
    }

    function setSigners(address[] calldata signers) public {
        _requireAccess(msg.sender, SET_SIGNERS);
        _setSigners(signers);
    }

    function _setSigners(address[] memory signers) internal {
        Core._setSigners(signers);
        emit Lens_App_SignersSet(signers);
    }

    function setPaymaster(address paymaster) public {
        _requireAccess(msg.sender, SET_PAYMASTER);
        _setPaymaster(paymaster);
    }

    function _setPaymaster(address paymaster) internal {
        Core._setPaymaster(paymaster);
        emit Lens_App_PaymasterAdded(paymaster);
        emit Lens_App_DefaultPaymasterSet(paymaster);
    }

    function setTreasury(address treasury) public {
        _requireAccess(msg.sender, SET_TREASURY);
        _setTreasury(treasury);
    }

    function _setTreasury(address treasury) internal {
        Core._setTreasury(treasury);
        emit Lens_App_TreasurySet(treasury);
    }

    function setMetadataURI(string calldata metadataURI) public override {
        _requireAccess(msg.sender, SET_METADATA);
        _setMetadataURI(metadataURI);
    }

    function _setMetadataURI(string memory metadataURI) internal {
        Core._setMetadataURI(metadataURI);
        emit Lens_App_MetadataURISet(metadataURI);
    }

    function setExtraData(DataElement[] calldata extraDataToSet) public override {
        _requireAccess(msg.sender, SET_EXTRA_DATA);
        _setExtraData(extraDataToSet);
    }

    function _setExtraData(DataElement[] memory extraDataToSet) internal {
        Core._setExtraData(extraDataToSet);
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            emit Lens_App_ExtraDataSet(extraDataToSet[i].key, extraDataToSet[i].value, extraDataToSet[i].value);
        }
    }

    //////////////////////////////////////////////////////////////////////////
    // Getters
    //////////////////////////////////////////////////////////////////////////

    function getGraphs() public view returns (address[] memory) {
        return Core.$storage().graphs;
    }

    function getFeeds() public view returns (address[] memory) {
        return Core.$storage().feeds;
    }

    function getUsernames() public view returns (address[] memory) {
        return Core.$storage().usernames;
    }

    function getCommunities() public view returns (address[] memory) {
        return Core.$storage().communities;
    }

    function getDefaultGraph() public view returns (address) {
        return Core.$storage().defaultGraph;
    }

    function getDefaultFeed() public view returns (address) {
        return Core.$storage().defaultFeed;
    }

    function getDefaultUsername() public view returns (address) {
        return Core.$storage().defaultUsername;
    }

    function getDefaultCommunity() public view returns (address) {
        return Core.$storage().defaultCommunity;
    }

    function getSigners() public view returns (address[] memory) {
        return Core.$storage().signers;
    }

    function getExtraData(bytes32 key) external view override returns (bytes memory) {
        return Core.$storage().extraData[key];
    }

    function getMetadataURI() external view override returns (string memory) {
        return Core.$storage().metadataURI;
    }
}
