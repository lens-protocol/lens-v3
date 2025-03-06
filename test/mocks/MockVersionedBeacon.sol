// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IVersionedBeacon} from "@core/interfaces/IVersionedBeacon.sol";

contract MockVersionedBeacon is IVersionedBeacon {
    function testMockVersionedBeacon() public {
        // Prevents being included in the foundry coverage report
    }

    address _mockedImplementation;
    mapping(uint256 => address) internal _mockedImplementations;

    function implementation() external view override returns (address) {
        return _mockedImplementation;
    }

    function implementation(uint256 implementationVersion) external view override returns (address) {
        return _mockedImplementations[implementationVersion];
    }

    function mockImplementation(address mockedImplementation) external {
        _mockedImplementation = mockedImplementation;
    }

    function mockImplementationForVersion(uint256 version, address mockedImplementation) external {
        _mockedImplementations[version] = mockedImplementation;
    }
}
