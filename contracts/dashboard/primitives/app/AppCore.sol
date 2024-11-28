// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.17;

import "./../../../core/libraries/ExtraDataLib.sol";

struct ArrayStorageHelper {
    uint8 index;
    bool isSet;
}

library AppCore {
    using ExtraDataLib for mapping(bytes32 => bytes);

    // Storage

    struct Storage {
        string metadataURI; // Name, description, logo, other attribiutes like category/topic, etc.
        bool sourceStampVerificationEnabled;
        address treasury; // Can also be defined as a permission in the AC... and allow multiple revenue recipients!
        mapping(address => ArrayStorageHelper) signerStorageHelper;
        mapping(address => ArrayStorageHelper) paymasterStorageHelper;
        mapping(address => ArrayStorageHelper) graphStorageHelper;
        mapping(address => ArrayStorageHelper) feedStorageHelper;
        mapping(address => ArrayStorageHelper) usernameStorageHelper;
        mapping(address => ArrayStorageHelper) groupStorageHelper;
        address[] signers;
        address[] paymasters;
        address[] graphs;
        address[] feeds;
        address[] usernames;
        address[] groups;
        address defaultGraph;
        address defaultFeed;
        address defaultUsername;
        address defaultGroup;
        address defaultPaymaster;
        mapping(bytes32 => bytes) extraData;
    }

    // keccak256('lens.app.core.storage')
    bytes32 constant CORE_STORAGE_SLOT = 0x13ac6c950512eee7a16ca70c4437c8719ba8e39704daf190995c963091228bf5;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := CORE_STORAGE_SLOT
        }
    }

    function _add(
        address element,
        address[] storage array,
        mapping(address => ArrayStorageHelper) storage arrayHelper
    ) internal {
        require(!arrayHelper[element].isSet, "ALREADY_ADDED");
        array.push(element);
        arrayHelper[element] = ArrayStorageHelper({index: uint8(array.length - 1), isSet: true});
    }

    function _remove(
        address element,
        address[] storage array,
        mapping(address => ArrayStorageHelper) storage arrayHelper
    ) internal {
        require(arrayHelper[element].isSet, "NOT_FOUND");
        uint256 index = arrayHelper[element].index;
        array[index] = array[array.length - 1];
        arrayHelper[array[index]].index = uint8(index);
        array.pop();
        delete arrayHelper[element];
    }

    ////////////// Graph

    function _addGraph(address graph) internal {
        _add(graph, $storage().graphs, $storage().graphStorageHelper);
    }

    function _removeGraph(address graph) internal {
        _remove(graph, $storage().graphs, $storage().graphStorageHelper);
    }

    function _setDefaultGraph(address graph) internal returns (bool) {
        bool wasAValuePreviouslySet = $storage().defaultGraph != address(0);
        if (graph != address(0)) {
            // address(0) allowed as a way to remove the default graph
            require($storage().graphStorageHelper[graph].isSet, "NOT_FOUND");
        }
        $storage().defaultGraph = graph;
        return wasAValuePreviouslySet;
    }

    ////////////// Feed

    function _addFeed(address feed) internal {
        _add(feed, $storage().feeds, $storage().feedStorageHelper);
    }

    function _removeFeed(address feed) internal {
        _remove(feed, $storage().feeds, $storage().feedStorageHelper);
    }

    function _setDefaultFeed(address feed) internal {
        $storage().defaultFeed = feed;
    }

    ////////////// Username

    function _addUsername(address username) internal {
        _add(username, $storage().usernames, $storage().usernameStorageHelper);
    }

    function _removeUsername(address username) internal {
        _remove(username, $storage().usernames, $storage().usernameStorageHelper);
    }

    function _setDefaultUsername(address username) internal returns (bool) {
        bool wasAValuePreviouslySet = $storage().defaultUsername != address(0);
        if (username != address(0)) {
            // address(0) allowed as a way to remove the default username
            require($storage().usernameStorageHelper[username].isSet, "NOT_FOUND");
        }
        $storage().defaultUsername = username;
        return wasAValuePreviouslySet;
    }

    ////////////// Group

    function _addGroup(address group) internal {
        _add(group, $storage().groups, $storage().groupStorageHelper);
    }

    function _removeGroup(address group) internal {
        _remove(group, $storage().groups, $storage().groupStorageHelper);
    }

    function _setDefaultGroup(address group) internal {
        if (group != address(0)) {
            // address(0) allowed as a way to remove the default group
            require($storage().groupStorageHelper[group].isSet, "NOT_FOUND");
        }
        $storage().defaultGroup = group;
    }

    ////////////// Paymaster

    function _addPaymaster(address paymaster) internal {
        _add(paymaster, $storage().paymasters, $storage().paymasterStorageHelper);
    }

    function _removePaymaster(address paymaster) internal {
        _remove(paymaster, $storage().paymasters, $storage().paymasterStorageHelper);
    }

    function _setDefaultPaymaster(address paymaster) internal returns (bool) {
        bool wasAValuePreviouslySet = $storage().defaultPaymaster != address(0);
        if (paymaster != address(0)) {
            // address(0) allowed as a way to remove the default paymaster
            require($storage().paymasterStorageHelper[paymaster].isSet, "NOT_FOUND");
        }
        $storage().defaultPaymaster = paymaster;
        return wasAValuePreviouslySet;
    }

    ////////////// Signer

    function _addSigner(address signer) internal {
        _add(signer, $storage().signers, $storage().signerStorageHelper);
    }

    function _removeSigner(address signer) internal {
        _remove(signer, $storage().signers, $storage().signerStorageHelper);
    }

    ////////////// Treasury

    function _setTreasury(address treasury) internal {
        $storage().treasury = treasury;
    }

    ////////////// Metadata URI

    function _setMetadataURI(string memory metadataURI) internal {
        $storage().metadataURI = metadataURI;
    }

    ////////////// Extra Data

    function setExtraData(KeyValue memory extraDataToSet) external returns (bool) {
        return _setExtraData(extraDataToSet);
    }

    function _setExtraData(KeyValue memory extraDataToSet) internal returns (bool) {
        return $storage().extraData.set(extraDataToSet);
    }
}
