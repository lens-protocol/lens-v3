// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

interface IVersionedBeacon {
    /**
     * @dev Returns the default implementation held by the Beacon. Usually this will be the latest or the most
     * stable version.
     * @return Address of the implementation.
     */
    function implementation() external view returns (address);

    /**
     * @dev Returns the implementation that corresponds to the requested version.
     * @param implementationVersion Version of the implementation to return.
     * @return Address of the implementation.
     */
    function implementation(uint256 implementationVersion) external view returns (address);
}
