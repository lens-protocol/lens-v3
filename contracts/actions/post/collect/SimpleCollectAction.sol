// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ISimpleCollectAction, CollectActionData} from "contracts/actions/post/collect/ISimpleCollectAction.sol";
import {IFeed} from "contracts/core/interfaces/IFeed.sol";
import {IGraph} from "contracts/core/interfaces/IGraph.sol";
import {LensCollectedPost} from "contracts/actions/post/collect/LensCollectedPost.sol";
import {OwnableMetadataBasedPostAction} from "contracts/actions/post/base/OwnableMetadataBasedPostAction.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {KeyValue, RecipientData} from "contracts/core/types/Types.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {BPS_MAX} from "contracts/core/types/Constants.sol";
import {LensPaymentHandler} from "contracts/extensions/fees/LensPaymentHandler.sol";

error InvalidSplits();
error InvalidRecipient();

contract SimpleCollectAction is
    ISimpleCollectAction,
    LensPaymentHandler,
    OwnableMetadataBasedPostAction,
    Initializable
{
    using SafeERC20 for IERC20;

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
    /// @custom:keccak lens.param.recipients
    bytes32 constant PARAM__RECIPIENTS = 0x7f7e01c87d5278dd08505253491cf5d6b30930036f6afa2ae22a980882f2cac1;
    /// @custom:keccak lens.param.referralFee
    bytes32 constant PARAM__REFERRAL_FEE = 0x6dff2c1710f2154b19d8cf5d6f7d8f5b3909222c3cdd8801486403e4d423b1b6;
    /// @custom:keccak lens.param.graph
    bytes32 constant PARAM__FOLLOWER_ONLY_GRAPH = 0x7d50408405f482949cd317ab452b66f1104c85a1708ae5be893385b1c898c6d9;
    /// @custom:keccak lens.param.isImmutable
    bytes32 constant PARAM__IS_IMMUTABLE = 0x4d1cad3e438026974130ac84979964dd6019eace55216c3de16bc79e36a4c44b;
    /// @custom:keccak lens.param.referrals
    bytes32 constant PARAM__REFERRALS = 0x183a1b7fdb9626f5ae4e8cac88ee13cc03b29800d2690f61e2a2566f76d8773f;

    /**
     * @notice A struct containing the params to configure this Collect Module on a post.
     *
     * @param amount The collecting cost associated with this post. 0 for free collect.
     * @param collectLimit The maximum number of collects for this publication. 0 for no limit.
     * @param token The token associated with this publication.
     * @param endTimestamp The end timestamp after which collecting is impossible. 0 for no expiry.
     * @param followerOnlyGraph The graph that holds the follow relations that restrict who can collect this post.
     * @param recipients Recipient(s) of collect fees.
     * @param referralFeeBps The fee percentage that is distributed to referrals.
     * @param isImmutable If true, it means that:
     *          - The Post URI is snapshotted at configuration time and cannot be changed later.
     *          - Collected posts' NFTs remain permanently available.
     *          - What you see is what you get; editing the Post URI or deleting the post will disable collection.
     *         Note: This immutability is only guaranteed if the URI is hosted on immutable storage. Mutability inherent
     *         to the chosen storage technology exceeds the on-chain verification capabilities.
     */
    struct CollectActionConfigureParams {
        uint160 amount; ///////////// (Optional) Default: 0
        uint96 collectLimit; //////// (Optional) Default: 0
        address token; /////////// (Optional, but required if amount > 0) Default: address(0)
        uint72 endTimestamp; //////// (Optional) Default: 0
        address followerOnlyGraph; // (Optional) Default: address(0)
        uint16 referralFeeBps; //////// (Optional) Default: 0
        RecipientData[] recipients; ////////// (Optional, but required if amount > 0)
        bool isImmutable; /////////// (Optional) Default: true
    }

    /**
     * @notice A struct containing the params to execute a collect action on a post.
     * @notice Both should be either 0 (if optional) or both should be non-zero if required by collect configuration.
     *
     * @param amountToPay The amount to pay for collect.
     * @param paymentToken The token to pay for collect.
     * @param treasury Recipient of the treasury fees.
     * @param referrals Recipients of the referral fees.
     */
    struct CollectActionExecutionParams {
        uint256 amountToPay; //// (Optional) Default: 0
        address paymentToken; // (Optional, but required if amount > 0) Default: address(0)
        RecipientData[] referrals;
    }

    constructor(address actionHub) OwnableMetadataBasedPostAction(actionHub, address(0), "") {
        _disableInitializers();
    }

    function initialize(address owner, string memory metadataURI) external initializer {
        OwnableMetadataBasedPostAction._initialize(owner, metadataURI);
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
            // This is an Initial collect configuration - we just store the data and
            // create and deploy the Lens Collected Post contract.
            address collectionAddress = address(new LensCollectedPost(feed, postId, configData.isImmutable));
            _storeCollectParams(feed, postId, configData, collectionAddress);
        } else {
            // Editing existing collect action config (it may or may not have collects made already)
            if (storedData.isImmutable) {
                // Cannot reconfigure anything in the immutable collect.
                revert Errors.Immutable();
            } else {
                // Non-immutable collect can be reconfigured (except making it immutable).
                storedData.amount = configData.amount;
                storedData.collectLimit = configData.collectLimit;
                storedData.token = configData.token;
                _updateRecipients(storedData, configData.recipients);
                storedData.referralFeeBps = configData.referralFeeBps;
                storedData.followerOnlyGraph = configData.followerOnlyGraph;
                storedData.endTimestamp = configData.endTimestamp;
                // Immutability cannot be flipped to true.
                require(configData.isImmutable == false, Errors.InvalidParameter());
            }
        }
        return abi.encode(storedData);
    }

    function _execute(address originalMsgSender, address feed, uint256 postId, KeyValue[] calldata params)
        internal
        override
        returns (bytes memory)
    {
        require(IFeed(feed).postExists(postId), Errors.DoesNotExist());
        CollectActionExecutionParams memory executionParams = _extractCollectActionExecutionParams(params);

        CollectActionData storage storedData = $collectDataStorage().collectData[feed][postId];
        uint256 tokenId = ++storedData.currentCollects;

        _validateCollect(originalMsgSender, feed, postId, executionParams);

        _processCollect(originalMsgSender, feed, postId, executionParams);

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
        /**
         * We allow to disable/enable collections that have not been configured yet, might be useful to disable,
         * configure, and enable it back after you double-checked your configuration.
         *
         * Immutable collections can also switch between disabled/enabled.
         */
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
            require(configData.recipients.length == 0, Errors.InvalidParameter());
            require(configData.referralFeeBps == 0, Errors.InvalidParameter());
        } else {
            // We expect token to support ERC-20 interface (call balanceOf and expect it to not revert)
            IERC20(configData.token).balanceOf(address(this));
            require(configData.recipients.length > 0, Errors.InvalidParameter());
            require(configData.referralFeeBps <= BPS_MAX, Errors.InvalidParameter());
        }
        if (configData.endTimestamp != 0 && configData.endTimestamp < block.timestamp) {
            revert Errors.InvalidParameter();
        }
        if (configData.followerOnlyGraph != address(0)) {
            // Check if the Graph supports isFollowing() interface with two random addresses
            IGraph(configData.followerOnlyGraph).isFollowing(address(this), msg.sender);
        }
        _validateRecipients(configData.recipients, true);
    }

    function _validateRecipients(RecipientData[] memory recipients, bool allowAddressZero) internal virtual {
        if (recipients.length > 0) {
            uint16 totalSplitBps = 0;
            for (uint256 i = 0; i < recipients.length; i++) {
                require(recipients[i].splitBps > 0, InvalidSplits());
                if (!allowAddressZero) {
                    require(recipients[i].recipient != address(0), InvalidRecipient());
                }
                totalSplitBps += recipients[i].splitBps;
            }
            require(totalSplitBps == BPS_MAX, InvalidSplits());
        }
    }

    function _storeRecipients(CollectActionData storage storedData, RecipientData[] memory recipients)
        internal
        virtual
    {
        for (uint256 i = 0; i < recipients.length; i++) {
            storedData.recipients.push(recipients[i]);
        }
    }

    // A weird update function, might fix later
    function _updateRecipients(CollectActionData storage storedData, RecipientData[] memory recipients)
        internal
        virtual
    {
        // Popping extra recipients from storage (if there were more existing than new ones)
        if (storedData.recipients.length > recipients.length) {
            uint256 recipientsToPop = storedData.recipients.length - recipients.length;
            for (uint256 i = 0; i < recipientsToPop; i++) {
                storedData.recipients.pop();
            }
        }
        // Filling in existing storage with new recipients (if there were any)
        for (uint256 i = 0; i < storedData.recipients.length; i++) {
            storedData.recipients[i] = recipients[i];
        }
        // Pushing new recipients to storage (if there are more new than existing ones)
        for (uint256 i = storedData.recipients.length; i < recipients.length; i++) {
            storedData.recipients.push(recipients[i]);
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
        _storeRecipients(storedData, configData.recipients);
        storedData.referralFeeBps = configData.referralFeeBps;
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

        if (data.collectLimit != 0 && data.currentCollects > data.collectLimit) {
            revert Errors.LimitReached();
        }

        if (expectedParams.amountToPay != data.amount || expectedParams.paymentToken != data.token) {
            revert Errors.InvalidParameter();
        }

        if (data.followerOnlyGraph != address(0)) {
            require(
                IGraph(data.followerOnlyGraph).isFollowing(originalMsgSender, IFeed(feed).getPostAuthor(postId)),
                Errors.NotFollowing()
            );
        }

        if (data.isImmutable) {
            // If post is edited to a different content, we fail so people do not collect an unexpected thing.
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

    function _processCollect(
        address originalMsgSender,
        address feed,
        uint256 postId,
        CollectActionExecutionParams memory executionParams
    ) internal virtual {
        CollectActionData storage data = $collectDataStorage().collectData[feed][postId];
        _handlePayment({
            payer: originalMsgSender,
            token: data.token,
            amount: data.amount,
            recipients: data.recipients,
            referrals: executionParams.referrals,
            referralFeeBps: data.referralFeeBps
        });
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
            referralFeeBps: 0,
            followerOnlyGraph: address(0),
            recipients: new RecipientData[](0),
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
            } else if (params[i].key == PARAM__REFERRAL_FEE) {
                configData.referralFeeBps = abi.decode(params[i].value, (uint16));
            } else if (params[i].key == PARAM__RECIPIENTS) {
                configData.recipients = abi.decode(params[i].value, (RecipientData[]));
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
            CollectActionExecutionParams({amountToPay: 0, paymentToken: address(0), referrals: new RecipientData[](0)});
        for (uint256 i = 0; i < params.length; i++) {
            if (params[i].key == PARAM__AMOUNT) {
                executionParams.amountToPay = abi.decode(params[i].value, (uint256));
            } else if (params[i].key == PARAM__TOKEN) {
                executionParams.paymentToken = abi.decode(params[i].value, (address));
            } else if (params[i].key == PARAM__REFERRALS) {
                executionParams.referrals = abi.decode(params[i].value, (RecipientData[]));
            }
        }
        return executionParams;
    }
}
