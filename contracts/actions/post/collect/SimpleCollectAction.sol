// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ISimpleCollectAction, CollectActionData} from "contracts/actions/post/collect/ISimpleCollectAction.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {LensCollectedPost} from "contracts/actions/post/collect/LensCollectedPost.sol";
import {BasePostAction} from "contracts/actions/post/base/BasePostAction.sol";
import {MetadataBased} from "contracts/core/base/MetadataBased.sol";
import {KeyValue} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {PaymentHandler} from "contracts/core/base/PaymentHandler.sol";

contract SimpleCollectAction is ISimpleCollectAction, BasePostAction, PaymentHandler, MetadataBased {
    event Lens_Action_MetadataURISet(string metadataURI);

    struct CollectActionStorage {
        mapping(address => mapping(uint256 => CollectActionData)) collectData;
    }

    /// @custom:keccak lens.storage.SimpleCollectAction.CollectActionStorage
    bytes32 constant STORAGE__SIMPLE_COLLECT_ACTION = 0xa818dbc25de051abcaa7f2eef0c43fdf86f365dfc6389654719cb8486eace5a5;

    function $collectDataStorage() private pure returns (CollectActionStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__SIMPLE_COLLECT_ACTION
        }
    }

    /// @custom:keccak lens.param.amount
    bytes32 constant PARAM__AMOUNT = 0xc8a06abcb0f2366f32dc2741bdf075c3215e3108918311ec0ac742f1ffd37f49;
    /// @custom:keccak lens.param.token
    bytes32 constant PARAM__TOKEN = 0xee737c77be2981e91c179485406e6d793521b20aca5e2137b6c497949a74bc94;
    /// @custom:keccak lens.param.collectLimit
    bytes32 constant PARAM__COLLECT_LIMIT = 0xa3a202292a3a2b62eecfeb02565126445fa5c792f06c6222157d3244eca405d5;
    /// @custom:keccak lens.param.endTimestamp
    bytes32 constant PARAM__END_TIMESTAMP = 0xe2a4a768f409ba480a321a7d36ec9da16e9eae60a25bb0aeccf334822cc859a8;
    /// @custom:keccak lens.param.recipient
    bytes32 constant PARAM__RECIPIENT = 0xa402f27be0e1380b17f8a7ab131394fbdf24cd8b5c2745bd842d1ae1668867ff;
    /// @custom:keccak lens.param.graph
    bytes32 constant PARAM__FOLLOWER_ONLY_GRAPH = 0x7d50408405f482949cd317ab452b66f1104c85a1708ae5be893385b1c898c6d9;
    /// @custom:keccak lens.param.isImmutable
    bytes32 constant PARAM__IS_IMMUTABLE = 0x4d1cad3e438026974130ac84979964dd6019eace55216c3de16bc79e36a4c44b;

    /**
     * @notice A struct containing the params to configure this Collect Module on a post.
     *
     * @param amount The collecting cost associated with this post. 0 for free collect.
     * @param token The token associated with this publication.
     * @param collectLimit The maximum number of collects for this publication. 0 for no limit.
     * @param endTimestamp The end timestamp after which collecting is impossible. 0 for no expiry.
     * @param recipient Recipient of collect fees.
     */
    struct CollectActionConfigureParams {
        uint160 amount; ///////////// (Optional) Default: 0
        uint96 collectLimit; //////// (Optional) Default: 0
        address token; /////////// (Optional, but required if amount > 0) Default: address(0)
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
     * @param token The token to pay for collect.
     */
    struct CollectActionExecutionParams {
        uint256 amount; //// (Optional) Default: 0
        address token; // (Optional, but required if amount > 0) Default: address(0)
    }

    constructor(address actionHub, string memory metadataURI) BasePostAction(actionHub) {
        _setMetadataURI(metadataURI);
    }

    function _emitMetadataURISet(string memory metadataURI) internal override {
        emit Lens_Action_MetadataURISet(metadataURI);
    }

    function _configure(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        internal
        override
        returns (bytes memory)
    {
        _validateSenderIsAuthor(originalMsgSender, feed, postId);

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
                revert Errors.Immutable();
            } else {
                storedData.amount = configData.amount;
                storedData.collectLimit = configData.collectLimit;
                storedData.token = configData.token;
                storedData.recipient = configData.recipient;
                storedData.followerOnlyGraph = configData.followerOnlyGraph;
                storedData.endTimestamp = configData.endTimestamp;
                // storedData.isImmutable = configData.isImmutable;
                // TODO: Cannot make it immutable if it wasn't before, because ContentURI is not immutable, unless we
                // would figure out a way to trigger a switch in LensCollectedPost contract.
            }
        }
        return abi.encode(storedData);
    }

    function _execute(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        internal
        override
        returns (bytes memory)
    {
        CollectActionExecutionParams memory expectedParams = _extractCollectActionExecutionParams(params);

        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];
        uint256 tokenId = ++storedData.currentCollects;

        _validateCollect(originalMsgSender, feed, postId, expectedParams);

        _processCollect(originalMsgSender, feed, postId);

        LensCollectedPost(storedData.collectionAddress).mint(originalMsgSender, tokenId);

        return abi.encode(tokenId);
    }

    function _setDisabled(
        address originalMsgSender,
        address feed,
        uint256 postId,
        bool isDisabled,
        KeyValue[] calldata /* params */
    ) internal override returns (bytes memory) {
        _validateSenderIsAuthor(originalMsgSender, feed, postId);
        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];
        // We don't check for existence of collect before disabling, because it might be useful to disable it initially
        // require(storedData.collectionAddress != address(0), Errors.DoesNotExist());
        require(!storedData.isImmutable, Errors.Immutable());
        require(storedData.isDisabled != isDisabled, Errors.RedundantStateChange());
        storedData.isDisabled = isDisabled;
        return abi.encode(isDisabled);
    }

    function getCollectActionData(address feed, uint256 postId) external view returns (CollectActionData memory) {
        return $collectDataStorage().collectData[feed][postId];
    }

    function _validateSenderIsAuthor(address sender, address feed, uint256 postId) internal virtual {
        if (sender != IFeed(feed).getPostAuthor(postId)) {
            revert Errors.InvalidMsgSender();
        }
    }

    function _validateConfigureParams(CollectActionConfigureParams memory configData) internal virtual {
        if (configData.amount == 0) {
            require(configData.token == address(0), Errors.InvalidParameter());
        } else {
            require(configData.token != address(0), Errors.InvalidParameter());
        }
        if (configData.endTimestamp != 0 && configData.endTimestamp < block.timestamp) {
            revert Errors.InvalidParameter();
        }
        if (configData.followerOnlyGraph != address(0)) {
            // Check if the Graph supports isFollowing() interface with two random addresses
            IGraph(configData.followerOnlyGraph).isFollowing(address(this), msg.sender);
        }
    }

    function _storeCollectParams(
        address feed,
        uint256 postId,
        CollectActionConfigureParams memory configData,
        address collectionAddress
    ) internal virtual {
        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];
        storedData.amount = configData.amount;
        storedData.collectLimit = configData.collectLimit;
        storedData.token = configData.token;
        storedData.recipient = configData.recipient;
        storedData.endTimestamp = configData.endTimestamp;
        storedData.followerOnlyGraph = configData.followerOnlyGraph;
        storedData.collectionAddress = collectionAddress;
        storedData.isImmutable = configData.isImmutable;
    }

    function _validateCollect(
        address originalMsgSender,
        address feed,
        uint256 postId,
        CollectActionExecutionParams memory expectedParams
    ) internal virtual {
        CollectActionData storage data = $collectDataStorage().collectData[feed][postId];

        require(data.collectionAddress != address(0), Errors.DoesNotExist());

        if (data.endTimestamp != 0 && block.timestamp > data.endTimestamp) {
            revert Errors.Expired();
        }

        if (data.collectLimit != 0 && data.currentCollects + 1 > data.collectLimit) {
            revert Errors.LimitReached();
        }

        if (expectedParams.amount != data.amount || expectedParams.token != data.token) {
            revert Errors.InvalidParameter();
        }

        if (data.followerOnlyGraph != address(0)) {
            require(
                IGraph(data.followerOnlyGraph).isFollowing(originalMsgSender, IFeed(feed).getPostAuthor(postId)),
                Errors.NotFollowing()
            );
        }

        if (data.isImmutable) {
            // TODO: There might be some edge-cases here (e.g. maybe also worth checking LensCollectedPost.isImmutable)
            string memory contentURI = IFeed(feed).getPost(postId).contentURI;
            require(
                keccak256(bytes(contentURI))
                    == keccak256(bytes(LensCollectedPost(data.collectionAddress).tokenURI(data.currentCollects))),
                Errors.InvalidParameter()
            );
        }

        if (data.isDisabled) {
            revert Errors.Disabled();
        }
    }

    function _processCollect(address originalMsgSender, address feed, uint256 postId) internal virtual {
        CollectActionData storage data = $collectDataStorage().collectData[feed][postId];

        uint256 amount = data.amount;
        address token = data.token;
        address recipient = data.recipient;

        if (amount > 0) {
            _handlePayment(token, originalMsgSender, recipient, amount);
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
            token: address(0),
            endTimestamp: 0,
            followerOnlyGraph: address(0),
            recipient: address(0),
            isImmutable: true
        });

        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__AMOUNT) {
                configData.amount = abi.decode(params[i].value, (uint160));
            } else if (params[i].key == PARAM__TOKEN) {
                configData.token = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__COLLECT_LIMIT) {
                configData.collectLimit = abi.decode(params[i].value, (uint96));
            } else if (params[i].key == PARAM__END_TIMESTAMP) {
                configData.endTimestamp = abi.decode(params[i].value, (uint72));
            } else if (params[i].key == PARAM__RECIPIENT) {
                configData.recipient = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__FOLLOWER_ONLY_GRAPH) {
                configData.followerOnlyGraph = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__IS_IMMUTABLE) {
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
            CollectActionExecutionParams({amount: 0, token: address(0)});

        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__AMOUNT) {
                executionParams.amount = abi.decode(params[i].value, (uint256));
            } else if (params[i].key == PARAM__TOKEN) {
                executionParams.token = abi.decode(params[i].value, (address));
            }
        }
        return executionParams;
    }
}
