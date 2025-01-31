// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "contracts/core/libraries/KeyValueStorageLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

struct ArrayStorageHelper {
    uint8 index;
    bool isSet;
}

library AppCore {
    using KeyValueStorageLib for mapping(bytes32 => bytes);

    // Storage

    struct Storage {
        bool sourceStampVerificationEnabled;
        address treasury; // Can also be defined as a permission in the AC... and allow multiple revenue recipients!
        mapping(address => ArrayStorageHelper) signerStorageHelper;
        mapping(address => ArrayStorageHelper) paymasterStorageHelper;
        mapping(address => ArrayStorageHelper) graphStorageHelper;
        mapping(address => ArrayStorageHelper) feedStorageHelper;
        mapping(address => ArrayStorageHelper) namespaceStorageHelper;
        mapping(address => ArrayStorageHelper) groupStorageHelper;
        address[] signers;
        address[] paymasters;
        address[] graphs;
        address[] feeds;
        address[] namespaces;
        address[] groups;
        address defaultGraph;
        address defaultFeed;
        address defaultNamespace;
        address defaultGroup;
        address defaultPaymaster;
        mapping(bytes32 => bytes) extraData;
    }

    /// @custom:keccak lens.storage.AppCore
    bytes32 constant STORAGE__APP_CORE = 0x00d742ba6838b80a9db3f3500fd0588118c5ae3a7f39bc9da201d6bdb2a0151a;

    function $storage() internal pure returns (Storage storage _storage) {
        assembly {
            _storage.slot := STORAGE__APP_CORE
        }
    }

    function _add(address element, address[] storage array, mapping(address => ArrayStorageHelper) storage arrayHelper)
        internal
    {
        require(element != address(0), Errors.InvalidParameter());
        require(!arrayHelper[element].isSet, Errors.RedundantStateChange());
        array.push(element);
        require(array.length <= type(uint8).max, Errors.LimitReached());
        arrayHelper[element] = ArrayStorageHelper({index: uint8(array.length - 1), isSet: true});
    }

    function _remove(
        address element,
        address[] storage array,
        mapping(address => ArrayStorageHelper) storage arrayHelper
    ) internal {
        require(arrayHelper[element].isSet, Errors.NotFound());
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
            require($storage().graphStorageHelper[graph].isSet, Errors.NotFound());
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

    function _setDefaultFeed(address feed) internal returns (bool) {
        bool wasAValuePreviouslySet = $storage().defaultFeed != address(0);
        if (feed != address(0)) {
            // address(0) allowed as a way to remove the default feed
            require($storage().feedStorageHelper[feed].isSet, Errors.NotFound());
        }
        $storage().defaultFeed = feed;
        return wasAValuePreviouslySet;
    }

    function _isFeedPresent(address feed) internal view returns (bool) {
        return $storage().feedStorageHelper[feed].isSet;
    }

    ////////////// Namespace

    function _addNamespace(address namespace) internal {
        _add(namespace, $storage().namespaces, $storage().namespaceStorageHelper);
    }

    function _removeNamespace(address namespace) internal {
        _remove(namespace, $storage().namespaces, $storage().namespaceStorageHelper);
    }

    function _setDefaultNamespace(address namespace) internal returns (bool) {
        bool wasAValuePreviouslySet = $storage().defaultNamespace != address(0);
        if (namespace != address(0)) {
            // address(0) allowed as a way to remove the default namespace
            require($storage().namespaceStorageHelper[namespace].isSet, Errors.NotFound());
        }
        $storage().defaultNamespace = namespace;
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
            require($storage().groupStorageHelper[group].isSet, Errors.NotFound());
        }
        $storage().defaultGroup = group;
    }

    function _isGroupPresent(address group) internal view returns (bool) {
        return $storage().groupStorageHelper[group].isSet;
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
            require($storage().paymasterStorageHelper[paymaster].isSet, Errors.NotFound());
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
}
