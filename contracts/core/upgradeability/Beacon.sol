// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {Ownable} from "contracts/core/access/Ownable.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";

contract Beacon is Ownable, IVersionedBeacon {
    event ImplementationSetForVersion(uint256 indexed version, address indexed implementation);
    event DefaultVersionSet(uint256 indexed version);

    mapping(uint256 => address) internal _implementations;
    uint256 internal _defaultVersion;

    constructor(address owner, uint256 version, address initialImplementation) Ownable() {
        _transferOwnership(owner);
        require(initialImplementation != address(0));
        _implementations[version] = initialImplementation;
        emit ImplementationSetForVersion(version, initialImplementation);
        _defaultVersion = version;
        emit DefaultVersionSet(version);
    }

    function implementation() external view override returns (address) {
        return _implementations[_defaultVersion];
    }

    function implementation(uint256 implementationVersion) external view override returns (address) {
        address implementationByVersion = _implementations[implementationVersion];
        require(implementationByVersion != address(0));
        return implementationByVersion;
    }

    function setImplementationForVersion(uint256 version, address implementationToSet) external onlyOwner {
        if (_defaultVersion == version) {
            require(implementationToSet != address(0));
        }
        _implementations[version] = implementationToSet;
        emit ImplementationSetForVersion(version, implementationToSet);
    }

    function setDefaultVersion(uint256 version) external onlyOwner {
        require(_implementations[version] != address(0));
        _defaultVersion = version;
        emit DefaultVersionSet(version);
    }
}
