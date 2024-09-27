// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

uint256 constant MODULE_TYPE_VALIDATION = 1;
uint256 constant MODULE_TYPE_EXECUTION = 2;
uint256 constant MODULE_TYPE_FALLBACK = 3;
uint256 constant MODULE_TYPE_HOOKS = 4;

// TODO: Maybe rename to I7579Module or IModule7579 - This applies to the rest of interfaces of this file
interface IModule {
    /**
     * @dev This function is called by the smart account during installation of the module
     * @param data arbitrary data that may be required on the module during `onInstall` initialization
     *
     * MUST revert on error (e.g. if module is already enabled)
     */
    function onInstall(bytes calldata data) external;

    /**
     * @dev This function is called by the smart account during uninstallation of the module
     * @param data arbitrary data that may be required on the module during `onUninstall` de-initialization
     *
     * MUST revert on error
     */
    function onUninstall(bytes calldata data) external;

    /**
     * @dev Returns boolean value if module is a certain type
     * @param moduleTypeId the module type ID according the ERC-7579 spec
     *
     * MUST return true if the module is of the given type and false otherwise
     */
    function isModuleType(uint256 moduleTypeId) external view returns (bool);
}

// From EIP-4337 ?
// https://github.com/eth-infinitism/account-abstraction/blob/9879c931ce92f0bee1bca1d1b1352eeb98b9a120/contracts/interfaces/PackedUserOperation.sol
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

interface IValidator is IModule {
    /**
     * @dev Validates a UserOperation
     * @param userOp the ERC-4337 PackedUserOperation
     * @param userOpHash the hash of the ERC-4337 PackedUserOperation
     *
     * MUST validate that the signature is a valid signature of the userOpHash
     * SHOULD return ERC-4337's SIG_VALIDATION_FAILED (and not revert) on signature mismatch
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash) external returns (uint256);

    /**
     * @dev Validates a signature using ERC-1271
     * @param sender the address that sent the ERC-1271 request to the smart account
     * @param hash the hash of the ERC-1271 request
     * @param signature the signature of the ERC-1271 request
     *
     * MUST return the ERC-1271 `MAGIC_VALUE` if the signature is valid
     * MUST NOT modify state
     */
    function isValidSignatureWithSender(address sender, bytes32 hash, bytes calldata signature)
        external
        view
        returns (bytes4);
}
