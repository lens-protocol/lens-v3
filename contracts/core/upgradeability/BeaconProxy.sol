// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";

contract BeaconProxy {
    event Upgraded(address indexed implementation);
    event BeaconUpgraded(address indexed beacon);
    event AdminChanged(address previousAdmin, address newAdmin);
    event AutoUpgradeChanged(bool enabled);

    struct BoolStorage {
        bool value;
    }

    struct AddressStorage {
        address value;
    }

    /// bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    bytes32 constant STORAGE__IMPLEMENTATION = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    /// bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)
    bytes32 constant STORAGE__BEACON = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
    /// bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1)
    bytes32 constant STORAGE__PROXY_ADMIN = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    /// bytes32(uint256(keccak256('eip1967.proxy.autoUpgrade')) - 1)
    bytes32 constant STORAGE__AUTO_UPGRADE = 0x124752f4f2ca9ee3c58e3394de18eda89b3da02e137cff10518a064f5ff4baaa;

    function $implementation() internal pure returns (AddressStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__IMPLEMENTATION
        }
    }

    function $beacon() internal pure returns (AddressStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__BEACON
        }
    }

    function $proxyAdmin() internal pure returns (AddressStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__PROXY_ADMIN
        }
    }

    function $autoUpgrade() internal pure returns (BoolStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__AUTO_UPGRADE
        }
    }

    constructor(address proxyAdmin, address beacon) {
        $proxyAdmin().value = proxyAdmin;
        emit AdminChanged(address(0), proxyAdmin);
        $autoUpgrade().value = true;
        emit AutoUpgradeChanged(true);
        $beacon().value = beacon;
        emit BeaconUpgraded(beacon);
        _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
    }

    function changeProxyAdmin(address proxyAdmin) external {
        require(msg.sender == $proxyAdmin().value);
        $proxyAdmin().value = proxyAdmin;
        emit AdminChanged(msg.sender, proxyAdmin);
    }

    function optOutFromAutoUpgrade() external {
        require(msg.sender == $proxyAdmin().value);
        $autoUpgrade().value = false;
        emit AutoUpgradeChanged(false);
    }

    function optInToAutoUpgrade() external {
        require(msg.sender == $proxyAdmin().value);
        $autoUpgrade().value = true;
        emit AutoUpgradeChanged(true);
        _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
    }

    function setImplementation(address implementation) external {
        require(msg.sender == $proxyAdmin().value);
        require($autoUpgrade().value == false);
        if (implementation != $implementation().value) {
            $implementation().value = implementation;
            emit Upgraded(implementation);
        }
    }

    function setBeacon(address beacon) external {
        require(msg.sender == $proxyAdmin().value);
        if (beacon != $beacon().value) {
            $beacon().value = beacon;
            emit BeaconUpgraded(beacon);
        }
        if ($autoUpgrade().value) {
            _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
        }
    }

    function triggerUpgradeToVersion(uint256 implementationVersion) external {
        require(msg.sender == $proxyAdmin().value);
        address implementationFromBeacon = IVersionedBeacon($beacon().value).implementation(implementationVersion);
        if (implementationFromBeacon != $implementation().value) {
            emit Upgraded(implementationFromBeacon);
            $implementation().value = implementationFromBeacon;
        }
    }

    function triggerUpgrade() external {
        require(msg.sender == $proxyAdmin().value);
        _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
    }

    // Function copied from @openzeppelin/contracts/proxy/Proxy.sol::_delegate
    function _delegateCallToImplementation(address implementation) internal virtual {
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
        if ($autoUpgrade().value) {
            implementation = _fetchImplFromBeaconAndAutoUpgradeIfNeeded();
        } else {
            implementation = $implementation().value;
        }
        return implementation;
    }

    function _fetchImplFromBeaconAndAutoUpgradeIfNeeded() internal returns (address) {
        address implementationFromBeacon = IVersionedBeacon($beacon().value).implementation();
        if (implementationFromBeacon != $implementation().value) {
            emit Upgraded(implementationFromBeacon);
            $implementation().value = implementationFromBeacon;
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
