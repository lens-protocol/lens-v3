// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DataElement} from "../../types/Types.sol";

library AppCore {
    // Storage

    struct Storage {
        string metadataURI; // Name, description, logo, other attribiutes like category/topic, etc.
        address treasury; // Can also be defined as a permission in the AC... and allow multiple revenue recipients!
        address[] graphs; // Graphs that this App uses.
        address[] feeds; // Feeds that this App uses
        address[] usernames; // Usernames that this App uses.
        address[] communities; // Communities that this App uses.
        address defaultGraph;
        address defaultFeed;
        address defaultUsername;
        address defaultCommunity;
        address defaultPaymaster;
        address[] signers; // Signers that belong to this App.
        address[] paymasters;
        mapping(bytes32 => bytes) extraData;
    }

    // keccak256('lens.app.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0x13ac6c950512eee7a16ca70c4437c8719ba8e39704daf190995c963091228bf5;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
        }
    }

    function _setGraph(address graph) internal {
        // TODO: Check for graph == 0x0, or add a add/remove function.
        if ($storage().graphs.length == 0) {
            $storage().graphs.push(graph);
            $storage().defaultGraph = graph;
        } else {
            $storage().graphs[0] = graph;
            $storage().defaultGraph = graph;
        }
    }

    // function setDefaultGraph(address graph) public {
    //     $storage().defaultGraph = graph;
    // }

    function _setFeeds(address[] memory feeds) internal returns (address) {
        $storage().feeds = feeds;
        if (feeds.length == 0) {
            delete $storage().defaultFeed;
            return address(0);
        } else {
            $storage().defaultFeed = feeds[0];
            return feeds[0];
        }
    }

    function _setDefaultFeed(address feed) internal {
        $storage().defaultFeed = feed;
    }

    function _addFeed(address feed) internal {
        // TODO: Add check for duplicate, or use a mapping.
        $storage().feeds.push(feed);
    }

    function _removeFeed(address feed, uint256 index) internal {
        if ($storage().feeds[index] == feed) {
            delete $storage().feeds[index];
        }
    }

    // TODO:
    // In this implementation we assume you can only have one username.

    function _setUsername(address username) internal {
        if ($storage().usernames.length == 0) {
            $storage().usernames.push(username);
            $storage().defaultUsername = username;
        } else {
            $storage().usernames[0] = username;
            $storage().defaultUsername = username;
        }
    }

    // function _setDefaultUsername(address username) internal {
    //     $storage().defaultUsername = username;
    // }

    function _setCommunity(address[] memory communities) internal returns (address) {
        $storage().communities = communities;
        if (communities.length == 0) {
            delete $storage().defaultCommunity;
            return address(0);
        } else {
            $storage().defaultCommunity = communities[0];
            return communities[0];
        }
    }

    function _setDefaultCommunity(address community) internal {
        $storage().defaultCommunity = community;
    }

    function _addCommunity(address community) internal {
        // TODO: Add check for duplicate, or use a mapping.
        $storage().communities.push(community);
    }

    function _removeCommunity(address community, uint256 index) internal {
        if ($storage().communities[index] == community) {
            delete $storage().communities[index];
        }
    }

    function _setSigners(address[] memory signers) internal {
        $storage().signers = signers;
    }

    function _setPaymaster(address paymaster) internal {
        if ($storage().paymasters.length == 0) {
            $storage().paymasters.push(paymaster);
            $storage().defaultPaymaster = paymaster;
        } else {
            $storage().paymasters[0] = paymaster;
            $storage().defaultPaymaster = paymaster;
        }
    }

    function _setTreasury(address treasury) internal {
        $storage().treasury = treasury;
    }

    function _setMetadataURI(string memory metadataURI) internal {
        $storage().metadataURI = metadataURI;
    }

    function _setExtraData(DataElement[] memory extraDataToSet) internal {
        for (uint256 i = 0; i < extraDataToSet.length; i++) {
            $storage().extraData[extraDataToSet[i].key] = extraDataToSet[i].value;
        }
    }
}
