// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";

contract PermissionlessAccessControl is IAccessControl {
    /// @custom:keccak lens.contract.AccessControl.PermissionlessAccessControl
    bytes32 constant CONTRACT_TYPE = 0xb5440aae9cc7331e30d1f5f4d93e4b545e210d2a6887783d935991d99a3c4dae;

    function getType() external pure returns (bytes32) {
        return CONTRACT_TYPE;
    }

    function canChangeAccessControl(address, /* account */ address /* contractAddress */ )
        external
        pure
        returns (bool)
    {
        return true;
    }

    function hasAccess(address, /* account */ address, /* contractAddress */ uint256 /* permissionId */ )
        external
        pure
        returns (bool)
    {
        return true;
    }
}
