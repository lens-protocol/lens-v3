// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {IVersionedBeacon} from "./IVersionedBeacon.sol";

contract Proxy {
    bool _autoUpgrade;
    address _currentImplementation;
    address _beacon;
    address _proxyAdmin;

    event ProxyAdminChanged(address indexed proxyAdmin);
    event Upgraded(address indexed implementation);
    event BeaconChanged(address indexed beacon);
    event AutoUpgrade(bool enabled);

    constructor(address proxyAdmin, address beacon) {
        _proxyAdmin = proxyAdmin;
        emit ProxyAdminChanged(proxyAdmin);
        _autoUpgrade = true;
        emit AutoUpgrade(true);
        _beacon = beacon;
        emit BeaconChanged(beacon);
        _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
    }

    function optOutFromAutoUpgrade() external {
        require(msg.sender == _proxyAdmin);
        _autoUpgrade = false;
        emit AutoUpgrade(false);
    }

    function optInFromAutoUpgrade() external {
        require(msg.sender == _proxyAdmin);
        _autoUpgrade = true;
        emit AutoUpgrade(true);
        _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
    }

    function setImplementation(
        address implementation
    ) external {
        require(msg.sender == _proxyAdmin);
        require(_autoUpgrade == false);
        if (implementation != _currentImplementation) {
            _currentImplementation = implementation;
            emit Upgraded(implementation);
        }
    }

    function setBeacon(
        address beacon
    ) external {
        require(msg.sender == _proxyAdmin);
        if (beacon != _beacon) {
            _beacon = beacon;
            emit BeaconChanged(beacon);
        }
        if (_autoUpgrade) {
            _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
        }
    }

    function triggerUpgrade(
        uint256 implementationVersion
    ) external {
        require(msg.sender == _proxyAdmin);
        address implementationFromBeacon = IVersionedBeacon(_beacon).implementation(implementationVersion);
        if (implementationFromBeacon != _currentImplementation) {
            emit Upgraded(implementationFromBeacon);
            _currentImplementation = implementationFromBeacon;
        }
    }

    function triggerUpgrade() external {
        require(msg.sender == _proxyAdmin);
        _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
    }

    // Function copied from @openzeppelin/contracts/proxy/Proxy.sol::_delegate
    function _delegateCallToImplementation(
        address implementation
    ) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _resolveImplementation() internal returns (address) {
        address implementation;
        if (_autoUpgrade) {
            implementation = _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
        } else {
            implementation = _currentImplementation;
        }
        return implementation;
    }

    function _fetchImplFromBeaconAndAutoUpgradeIfNeeded() internal returns (address) {
        address implementationFromBeacon = IVersionedBeacon(_beacon).implementation();
        if (implementationFromBeacon != _currentImplementation) {
            emit Upgraded(implementationFromBeacon);
            _currentImplementation = implementationFromBeacon;
        }
        return implementationFromBeacon;
    }

    function _proxyCall() internal {
        _delegateCallToImplementation(_resolveImplementation());
    }

    fallback() external payable {
        _proxyCall();
    }

    receive() external payable {
        _proxyCall();
    }
}
