// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {ISimpleCollectAction, CollectActionData, CollectActionData} from "./ISimpleCollectAction.sol";
import {IFeed} from "./../../core/interfaces/IFeed.sol";
import {IGraph} from "./../../core/interfaces/IGraph.sol";

import {LensCollectedPost} from "./LensCollectedPost.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {KeyValue} from "./../../core/types/Types.sol";

contract SimpleCollectAction is ISimpleCollectAction {
    using SafeERC20 for IERC20;

    struct CollectActionStorage {
        mapping(address => mapping(uint256 => CollectActionData)) collectData;
    }

    // keccak256('lens.simple.collect.action.storage')
    bytes32 constant SIMPLE_COLLECT_ACTION_STORAGE_SLOT =
        0xec3c61dac83a5e1c58a4edc68a1b1d187690a6379142dd5c3c7be1006dbe60f7;

    function $collectDataStorage() private pure returns (CollectActionStorage storage _storage) {
        assembly {
            _storage.slot := SIMPLE_COLLECT_ACTION_STORAGE_SLOT
        }
    }

    // keccak256("lens.actions.collect.SimpleCollectAction.param.key.amount");
    bytes32 immutable AMOUNT_PARAM_KEY = 0x51d27705e956fda3036fa0e06473280e805ad727991b5c04a7dd648006ee6516;
    // keccak256("lens.actions.collect.SimpleCollectAction.param.key.currency");
    bytes32 immutable CURRENCY_PARAM_KEY = 0xf4480a2542407ad170d4070fcb73508d7a7f0fa76228a5bc4a9f53807499c268;
    // keccak256("lens.actions.collect.SimpleCollectAction.param.key.collectLimit");
    bytes32 immutable COLLECT_LIMIT_PARAM_KEY = 0x59226908c34e8d25542cf48fcd8c1b4d8b21a10bbf52610f73743ac1b318013e;
    // keccak256("lens.actions.collect.SimpleCollectAction.param.key.endTimestamp");
    bytes32 immutable END_TIMESTAMP_PARAM_KEY = 0x6ce823f3b1902903a294181f25c7425553b4413066cb33e266594974e3a9abb5;
    // keccak256("lens.actions.collect.SimpleCollectAction.param.key.recipient");
    bytes32 immutable RECIPIENT_PARAM_KEY = 0xecf1d963892397e95e102ceadd1b1c1e9f0c9161c45f8353e84752d7cdaefbcd;
    // keccak256("lens.actions.collect.SimpleCollectAction.param.key.followerOnlyGraph");
    bytes32 immutable FOLLOWER_ONLY_GRAPH_PARAM_KEY = 0x022d08514a767b1bcb924fb7da6ce0de8f0d4972af8201900b707dc53b07b535;
    // keccak256("lens.actions.collect.SimpleCollectAction.param.key.isImmutable");
    bytes32 immutable IS_IMMUTABLE_PARAM_KEY = 0x2fdb09caa9ef7bd4957f8a9bddb15e864218fedbcd97e9f5944b386d1657c5cd;

    /**
     * @notice A struct containing the params to configure this Collect Module on a post.
     *
     * @param amount The collecting cost associated with this post. 0 for free collect.
     * @param currency The currency associated with this publication.
     * @param collectLimit The maximum number of collects for this publication. 0 for no limit.
     * @param endTimestamp The end timestamp after which collecting is impossible. 0 for no expiry.
     * @param recipient Recipient of collect fees.
     */
    struct CollectActionConfigureParams {
        uint160 amount; ///////////// (Optional) Default: 0
        uint96 collectLimit; //////// (Optional) Default: 0
        address currency; /////////// (Optional, but required if amount > 0) Default: address(0)
        uint72 endTimestamp; //////// (Optional) Default: 0
        address followerOnlyGraph; // (Optional) Default: address(0)
        address recipient; ////////// (Optional, but required if amount > 0) Default: address(0)
        bool isImmutable; /////////// (Optional) Default: true
    }

    /**
     * @notice A struct containing the params to execute a collect action on a post.
     * @notice Both should be either 0 (if optional) or both should be non-zero if required by collect configuration.
     *
     * @param amount The amount to pay for collect.
     * @param currency The currency to pay for collect.
     */
    struct CollectActionExecutionParams {
        uint256 amount; //// (Optional) Default: 0
        address currency; // (Optional, but required if amount > 0) Default: address(0)
    }

    function configure(
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external override returns (bytes memory) {
        _validateSenderIsAuthor(msg.sender, feed, postId);

        CollectActionConfigureParams memory configData = _extractConfigurationFromParams(params);
        _validateConfigureParams(configData);

        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];

        if (storedData.collectionAddress == address(0)) {
            // First time? :)
            // create and deploy the Lens Collected Post contract
            address collectionAddress = address(new LensCollectedPost(feed, postId, configData.isImmutable));
            _storeCollectParams(feed, postId, configData, collectionAddress);
        } else {
            // Editing existing collect action config
            if (storedData.isImmutable) {
                // TODO: Should we have two different bools? isImmutableConfig & isImmutableContentURI?
                revert("Cannot edit immutable collect");
            } else {
                storedData.amount = configData.amount;
                storedData.collectLimit = configData.collectLimit;
                storedData.currency = configData.currency;
                storedData.recipient = configData.recipient;
                storedData.followerOnlyGraph = configData.followerOnlyGraph;
                storedData.endTimestamp = configData.endTimestamp;
                // storedData.isImmutable = configData.isImmutable;
                // TODO: Cannot make it immutable if it wasn't before, because ContentURI is not immutable, unless we
                // would figure out a way to trigger a switch in LensCollectedPost contract.
            }
        }
        bytes memory encodedStoredData = abi.encode(storedData);
        emit Lens_PostAction_Configured(feed, postId, params, encodedStoredData);
        return encodedStoredData;
    }

    function execute(
        address feed,
        uint256 postId,
        KeyValue[] calldata params
    ) external override returns (bytes memory) {
        CollectActionExecutionParams memory expectedParams = _extractCollectActionExecutionParams(params);

        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];
        storedData.currentCollects++;

        _validateCollect(feed, postId, expectedParams);

        _processCollect(feed, postId);

        // TODO: Might want to move inside _processCollect?
        LensCollectedPost(storedData.collectionAddress).mint(msg.sender, storedData.currentCollects);

        emit Lens_PostAction_Executed(feed, postId, params, "");
        return "";
    }

    function getCollectActionData(address feed, uint256 postId) external view returns (CollectActionData memory) {
        return $collectDataStorage().collectData[feed][postId];
    }

    function _validateSenderIsAuthor(address sender, address feed, uint256 postId) internal virtual {
        if (sender != IFeed(feed).getPostAuthor(postId)) {
            revert("Sender is not the author");
        }
    }

    function _validateConfigureParams(CollectActionConfigureParams memory configData) internal virtual {
        if (configData.amount == 0) {
            require(configData.currency == address(0), "Invalid currency");
        } else {
            require(configData.currency != address(0), "Invalid currency");
        }
        if (configData.endTimestamp != 0 && configData.endTimestamp < block.timestamp) {
            revert("Invalid params");
        }
        if (configData.followerOnlyGraph != address(0)) {
            // Check if the Graph supports isFollowing() interface
            IGraph(configData.followerOnlyGraph).isFollowing(address(this), msg.sender);
        }
    }

    function _storeCollectParams(
        address feed,
        uint256 postId,
        CollectActionConfigureParams memory configData,
        address collectionAddress
    ) internal virtual {
        $collectDataStorage().collectData[feed][postId] = CollectActionData({
            amount: configData.amount,
            collectLimit: configData.collectLimit,
            currency: configData.currency,
            currentCollects: 0,
            recipient: configData.recipient,
            endTimestamp: configData.endTimestamp,
            followerOnlyGraph: configData.followerOnlyGraph,
            collectionAddress: collectionAddress,
            isImmutable: configData.isImmutable
        });
    }

    function _validateCollect(
        address feed,
        uint256 postId,
        CollectActionExecutionParams memory expectedParams
    ) internal virtual {
        CollectActionData storage data = $collectDataStorage().collectData[feed][postId];

        require(data.collectionAddress != address(0), "Collect not configured for this post");

        if (data.endTimestamp != 0 && block.timestamp > data.endTimestamp) {
            revert("Collect expired");
        }

        if (data.collectLimit != 0 && data.currentCollects + 1 > data.collectLimit) {
            revert("Collect limit exceeded");
        }

        if (expectedParams.amount != data.amount || expectedParams.currency != data.currency) {
            revert("Invalid expected amount and/or currency");
        }

        if (data.followerOnlyGraph != address(0)) {
            require(
                IGraph(data.followerOnlyGraph).isFollowing(msg.sender, IFeed(feed).getPostAuthor(postId)),
                "Not following"
            );
        }

        if (data.isImmutable) {
            // TODO: There might be some edge-cases here (e.g. maybe also worth checking LensCollectedPost.isImmutable)
            string memory contentURI = IFeed(feed).getPost(postId).contentURI;
            require(
                keccak256(bytes(contentURI))
                    == keccak256(bytes(LensCollectedPost(data.collectionAddress).tokenURI(data.currentCollects))),
                "Invalid content URI"
            );
        }
    }

    function _processCollect(address feed, uint256 postId) internal virtual {
        CollectActionData storage data = $collectDataStorage().collectData[feed][postId];

        uint256 amount = data.amount;
        address currency = data.currency;
        address recipient = data.recipient;

        if (amount > 0) {
            IERC20(currency).safeTransferFrom(msg.sender, recipient, amount);
        }
    }

    function _extractConfigurationFromParams(KeyValue[] calldata params)
        internal
        pure
        returns (CollectActionConfigureParams memory)
    {
        CollectActionConfigureParams memory configData = CollectActionConfigureParams({
            amount: 0,
            collectLimit: 0,
            currency: address(0),
            endTimestamp: 0,
            followerOnlyGraph: address(0),
            recipient: address(0),
            isImmutable: true
        });

        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == AMOUNT_PARAM_KEY) {
                configData.amount = abi.decode(params[i].value, (uint160));
            } else if (params[i].key == CURRENCY_PARAM_KEY) {
                configData.currency = abi.decode(params[i].value, (address));
            } else if (params[i].key == COLLECT_LIMIT_PARAM_KEY) {
                configData.collectLimit = abi.decode(params[i].value, (uint96));
            } else if (params[i].key == END_TIMESTAMP_PARAM_KEY) {
                configData.endTimestamp = abi.decode(params[i].value, (uint72));
            } else if (params[i].key == RECIPIENT_PARAM_KEY) {
                configData.recipient = abi.decode(params[i].value, (address));
            } else if (params[i].key == FOLLOWER_ONLY_GRAPH_PARAM_KEY) {
                configData.followerOnlyGraph = abi.decode(params[i].value, (address));
            } else if (params[i].key == IS_IMMUTABLE_PARAM_KEY) {
                configData.isImmutable = abi.decode(params[i].value, (bool));
            }
        }
        return configData;
    }

    function _extractCollectActionExecutionParams(KeyValue[] calldata params)
        internal
        pure
        returns (CollectActionExecutionParams memory)
    {
        CollectActionExecutionParams memory executionParams =
            CollectActionExecutionParams({amount: 0, currency: address(0)});

        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == AMOUNT_PARAM_KEY) {
                executionParams.amount = abi.decode(params[i].value, (uint256));
            } else if (params[i].key == CURRENCY_PARAM_KEY) {
                executionParams.currency = abi.decode(params[i].value, (address));
            }
        }
        return executionParams;
    }
}
