// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

interface IAccessControl {
    /**
     * Returns the implementation type of the access control.
     */
    function getType() external view returns (bytes32);

    /**
     * Returns true if the account is allowed to change the access control in the given contract address, false if not.
     *
     * @param account The account to check if is allowed to change the access control.
     * @param contractAddress The address where the access control is being changed.
     */
    function canChangeAccessControl(address account, address contractAddress) external view returns (bool);

    /**
     * Returns true if the account has granted access to the specified permission, false otherwise.
     * This function MUST NOT revert. Instead, return false.
     *
     * @param account The account to check if has access to a permission.
     * @param contractAddress The address where the permission is queried.
     * @param permissionId The ID of the permission.
     */
    function hasAccess(address account, address contractAddress, uint256 permissionId) external view returns (bool);
}
