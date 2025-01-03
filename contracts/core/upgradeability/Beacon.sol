// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";

contract Beacon is IVersionedBeacon {
    address internal _owner; // TODO: Ownable
    mapping(uint256 => address) internal _implementations;
    uint256 internal _latestVersion;

    function implementation() external view override returns (address) {
        return _implementations[_latestVersion];
    }

    function implementation(uint256 implementationVersion) external view override returns (address) {
        address implementationByVersion = _implementations[implementationVersion];
        require(implementationByVersion != address(0));
        return implementationByVersion;
    }

    function setImplementationForVersion(uint256 version, address implementationToSet) external {
        require(msg.sender == _owner);
        _implementations[version] = implementationToSet;
        // event
    }

    function setLatestVersion(uint256 version) external {
        require(msg.sender == _owner);
        require(_implementations[version] != address(0));
        _latestVersion = version;
        // event
    }

    function setLatestImplementation(uint256 version, address implementationToSet) external {
        require(msg.sender == _owner);
        require(implementationToSet != address(0));
        _implementations[version] = implementationToSet;
        _latestVersion = version;
        // events
    }
}
