// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMetadataBased} from "./../base/IMetadataBased.sol";
import {DataElement} from "./../../types/Types.sol";

interface IApp is IMetadataBased {
    event Lens_App_GraphAdded(address indexed graph);
    event Lens_App_DefaultGraphSet(address indexed graph);
    event Lens_App_FeedAdded(address indexed feed);
    event Lens_App_FeedRemoved(address indexed feed);
    event Lens_App_FeedsSet(address[] feeds);
    event Lens_App_DefaultFeedSet(address indexed feed);
    event Lens_App_UsernameAdded(address indexed username);
    event Lens_App_DefaultUsernameSet(address indexed username);
    event Lens_App_CommunityAdded(address indexed community);
    event Lens_App_CommunityRemoved(address indexed community);
    event Lens_App_CommunitiesSet(address[] communities);
    event Lens_App_DefaultCommunitySet(address indexed community);
    event Lens_App_PaymasterAdded(address indexed paymaster);
    event Lens_App_DefaultPaymasterSet(address indexed paymaster);
    event Lens_App_MetadataURISet(string metadataURI);
    event Lens_App_SignersSet(address[] signers);
    event Lens_App_ExtraDataSet(bytes32 indexed key, bytes value, bytes indexed valueIndexed);
    event Lens_App_TreasurySet(address indexed treasury);

    // Primitive-based setters

    function setCommunity(address[] memory communities) external;
    function setDefaultCommunity(address community) external;
    function addCommunity(address community) external;
    function removeCommunity(address community, uint256 index) external;

    function setGraph(address graph) external;

    function setFeeds(address[] memory feeds) external;
    function setDefaultFeed(address feed) external;
    function addFeed(address feed) external;
    function removeFeed(address feed, uint256 index) external;

    function setUsername(address username) external;

    // App Specific setters

    function setSigners(address[] memory signers) external;
    function setPaymaster(address paymaster) external;
    function setExtraData(DataElement[] calldata extraDataToSet) external;

    // Getters

    function getGraphs() external view returns (address[] memory);
    function getFeeds() external view returns (address[] memory);
    function getUsernames() external view returns (address[] memory);
    function getCommunities() external view returns (address[] memory);
    function getDefaultGraph() external view returns (address);
    function getDefaultFeed() external view returns (address);
    function getDefaultUsername() external view returns (address);
    function getDefaultCommunity() external view returns (address);
    function getSigners() external view returns (address[] memory);
    function getExtraData(bytes32 key) external view returns (bytes memory);
}
