// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "contracts/core/access/Ownable.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";
import {NATIVE_TOKEN} from "contracts/core/types/Constants.sol";

import {KeyValue} from "contracts/core/types/Types.sol";

contract TokenDistributor is Ownable, Initializable {
    using SafeERC20 for IERC20;

    event Lens_TokenDistributor_SignerUpdated(address indexed oldSigner, address indexed newSigner);

    event Lens_TokenDistributor_TransferSucceeded(
        uint256 indexed distributionId, bytes32 indexed batchId, address indexed recipient, uint256 amount
    );

    event Lens_TokenDistributor_TransferFailed(
        uint256 indexed distributionId, bytes32 indexed batchId, address indexed recipient, uint256 amount
    );

    event Lens_TokenDistributor_DistributionCreated(
        uint256 indexed distributionId, address indexed token, uint256 amount, KeyValue[] params
    );

    event Lens_TokenDistributor_DistributionEnded(uint256 indexed distributionId, uint256 withdrawnAmount);

    struct Distribution {
        address token;
        uint256 initialAmount;
        uint256 remainingAmount;
    }

    struct TokenTransfer {
        address recipient;
        uint256 amount;
    }

    struct TokenDistributorStorage {
        address signer;
        uint256 lastDistributionId;
        mapping(uint256 distributionId => Distribution distribution) distributions;
        mapping(uint256 distributionId => mapping(bytes32 batchId => bool batchProcessed)) wasBatchProcessed;
    }

    bytes32 constant DISTRIBUTE_TOKENS_TYPEHASH = keccak256(
        "DistributeTokens(uint256 distributionId,bytes32 batchId,TokenTransfer[] transfers,uint256 deadline)TokenTransfer(address recipient,uint256 amount)"
    );

    /// @custom:keccak lens.storage.TokenDistributor
    bytes32 constant STORAGE__TOKEN_DISTRIBUTOR = 0xdd92edd48247ec39dc282ea36076573b8a79476fbc92e4fa49507c701d8fcdd7;

    function $storage() internal pure returns (TokenDistributorStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__TOKEN_DISTRIBUTOR
        }
    }

    constructor(address owner) {
        _transferOwnership(owner);
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        _transferOwnership(owner);
    }

    function updateSigner(address newSigner) external onlyOwner {
        address oldSigner = $storage().signer;
        $storage().signer = newSigner;
        emit Lens_TokenDistributor_SignerUpdated(oldSigner, newSigner);
    }

    function createDistribution(address token, uint256 amount, KeyValue[] calldata params)
        external
        payable
        onlyOwner
        returns (uint256)
    {
        uint256 distributionId = ++$storage().lastDistributionId;
        require(amount > 0, Errors.InvalidParameter());
        _pullTokens(token, amount);
        $storage().distributions[distributionId] =
            Distribution({token: token, initialAmount: amount, remainingAmount: amount});
        // So far, KeyValue params are only bypassed to the event for indexers to use.
        emit Lens_TokenDistributor_DistributionCreated(distributionId, token, amount, params);
        return distributionId;
    }

    function endDistribution(uint256 distributionId) external onlyOwner {
        uint256 amountToWithdraw = $storage().distributions[distributionId].remainingAmount;
        require(amountToWithdraw > 0, Errors.RedundantStateChange());
        $storage().distributions[distributionId].remainingAmount = 0;
        _distributeTokensTo($storage().distributions[distributionId].token, msg.sender, amountToWithdraw);
        emit Lens_TokenDistributor_DistributionEnded(distributionId, amountToWithdraw);
    }

    function distributeTokens(
        uint256 distributionId,
        bytes32 batchId,
        TokenTransfer[] calldata transfers,
        uint256 amountToDistribute,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(deadline >= block.timestamp, Errors.Expired());
        _validateBatch(distributionId, batchId);
        _validateSignature(distributionId, batchId, transfers, deadline, signature);
        _markBatchAsProcessed(distributionId, batchId);
        _validateAmountToDistribute(distributionId, amountToDistribute);
        $storage().distributions[distributionId].remainingAmount -= amountToDistribute;
        address token = $storage().distributions[distributionId].token;
        uint256 distributedAmount;
        for (uint256 i = 0; i < transfers.length; i++) {
            if (_tryDistributeTokensTo(token, transfers[i].recipient, transfers[i].amount)) {
                distributedAmount += transfers[i].amount;
                emit Lens_TokenDistributor_TransferSucceeded(
                    distributionId, batchId, transfers[i].recipient, transfers[i].amount
                );
            } else {
                emit Lens_TokenDistributor_TransferFailed(
                    distributionId, batchId, transfers[i].recipient, transfers[i].amount
                );
            }
        }
        require(distributedAmount <= amountToDistribute, Errors.InvalidParameter());
        if (distributedAmount != amountToDistribute) {
            $storage().distributions[distributionId].remainingAmount += amountToDistribute - distributedAmount;
        } else if ($storage().distributions[distributionId].remainingAmount == 0) {
            // Distribution ended naturally by distributing all the initially allocated tokens.
            emit Lens_TokenDistributor_DistributionEnded(distributionId, 0);
        }
    }

    function _validateSignature(
        uint256 distributionId,
        bytes32 batchId,
        TokenTransfer[] calldata transfers,
        uint256 deadline,
        bytes memory signature
    ) internal view {
        bytes32 digest = _calculateDigest(distributionId, batchId, transfers, deadline);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        address signer = ecrecover(digest, v, r, s);
        require(signer == $storage().signer, Errors.WrongSigner());
    }

    function _calculateDigest(
        uint256 distributionId,
        bytes32 batchId,
        TokenTransfer[] calldata transfers,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(DISTRIBUTE_TOKENS_TYPEHASH, distributionId, batchId, _encodeForEIP712(transfers), deadline)
        );
    }

    function _encodeForEIP712(TokenTransfer memory tokenTransfer) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("TokenTransfer(address recipient,uint256 amount)"), // Type Hash
                tokenTransfer.recipient,
                tokenTransfer.amount
            )
        );
    }

    function _encodeForEIP712(TokenTransfer[] memory tokenTransferArray) internal pure returns (bytes32) {
        bytes32[] memory tokenTransferEncodedElements = new bytes32[](tokenTransferArray.length);
        for (uint256 i = 0; i < tokenTransferArray.length; i++) {
            tokenTransferEncodedElements[i] = _encodeForEIP712(tokenTransferArray[i]);
        }
        return _encodeForEIP712(tokenTransferEncodedElements);
    }

    function _encodeForEIP712(bytes32[] memory bytes32Array) internal pure returns (bytes32) {
        return keccak256(abi.encode(bytes32Array));
    }

    function _pullTokens(address token, uint256 amount) internal {
        if (token == NATIVE_TOKEN) {
            require(msg.value == amount, Errors.FailedToTransferNative());
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _validateBatch(uint256 distributionId, bytes32 batchId) internal view {
        require($storage().wasBatchProcessed[distributionId][batchId] == false, Errors.AlreadyProcessed());
    }

    function _markBatchAsProcessed(uint256 distributionId, bytes32 batchId) internal {
        $storage().wasBatchProcessed[distributionId][batchId] = true;
    }

    function _validateAmountToDistribute(uint256 distributionId, uint256 amountToDistribute) internal view {
        require(
            amountToDistribute <= $storage().distributions[distributionId].remainingAmount, Errors.InvalidParameter()
        );
    }

    function _tryDistributeTokensTo(address token, address recipient, uint256 amount) internal returns (bool) {
        bool transferSucceeded;
        if (token == NATIVE_TOKEN) {
            (transferSucceeded,) = recipient.call{value: amount}("");
        } else {
            IERC20(token).safeTransfer(recipient, amount);
            transferSucceeded = true;
        }
        return transferSucceeded;
    }

    function _distributeTokensTo(address token, address recipient, uint256 amount) internal {
        require(_tryDistributeTokensTo(token, recipient, amount), Errors.TransferFailed());
    }

    // Getters

    function getDistribution(uint256 distributionId) external view returns (Distribution memory) {
        return $storage().distributions[distributionId];
    }

    function getDistributionCount() external view returns (uint256) {
        return $storage().lastDistributionId;
    }

    function getSigner() external view returns (address) {
        return $storage().signer;
    }

    function wasBatchProcessed(uint256 distributionId, bytes32 batchId) external view returns (bool) {
        return $storage().wasBatchProcessed[distributionId][batchId];
    }
}
