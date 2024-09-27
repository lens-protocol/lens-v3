// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "../access-control/IAccessControl.sol";
import {AccessControlLib} from "../libraries/AccessControlLib.sol";
import {IValidator, MODULE_TYPE_VALIDATION, PackedUserOperation} from "./EIP7579.sol";

contract AccountManagersModule is IValidator {
    using AccessControlLib for IAccessControl;

    uint256 immutable ACCOUNT_MANAGER_SIGN_RID = uint256(keccak256("ACCOUNT_MANAGER_SIGN"));
    uint256 immutable ACCOUNT_MANAGER_EXECUTE_RID = uint256(keccak256("ACCOUNT_MANAGER_EXECUTE"));

    mapping(address => IAccessControl) _accessControl;

    function onInstall(bytes calldata data) external override {
        IAccessControl accessControl = IAccessControl(abi.decode(data, (address)));
        accessControl.verifyHasAccessFunction();
        _accessControl[msg.sender] = accessControl;
    }

    function onUninstall(bytes calldata data) external override {
        delete _accessControl[msg.sender];
    }

    function isModuleType(uint256 moduleTypeId) external view override returns (bool) {
        return moduleTypeId == EIP7579.MODULE_TYPE_VALIDATION;
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        override
        returns (uint256)
    {
        // MUST validate that the signature is a valid signature of the userOpHash
        address recoveredAddress = ECDSA.recover(userOpHash, userOp.signature);
        if (userOp.sender == recoveredAddress) {
            // // TODO: If we want granular we should build the RID from the userOp.callData
            // // I made some pseudocode of how this could be:
            // bytes4 selector = getFirst4BytesOf(userOp.callData);
            // uint256 resourceId = uint256(keccak256(selector));
            // // Then just do the next line but replacing the resourceId with the one we just calculated
            _accessControl[msg.sender].requireAccess({
                account: userOpHash.sender,
                resourceLocation: msg.sender,
                resourceId: ACCOUNT_MANAGER_EXECUTE_RID
            });
            return 0; // success?
        } else {
            // SHOULD return ERC-4337's SIG_VALIDATION_FAILED (and not revert) on signature mismatch
            return 1; // SIG_VALIDATION_FAILED?
        }
    }

    function isValidSignatureWithSender(address sender, bytes32 hash, bytes calldata signature)
        external
        view
        override
        returns (bytes4)
    {
        // TODO: Do we want to support this?
        if (
            _accessControl[msg.sender].hasAccess({
                account: ECDSA.recover(digest, signature), // Import OZ lib for this
                resourceLocation: sender,
                resourceId: ACCOUNT_MANAGER_SIGN_RID
            })
        ) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }
}
