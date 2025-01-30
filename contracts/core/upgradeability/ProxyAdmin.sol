// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ILock} from "contracts/core/interfaces/ILock.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

contract ProxyAdmin is Ownable {
    using CallLib for address;

    ILock immutable LOCK;

    constructor(address proxyAdminOwner, address lock) Ownable() {
        _transferOwnership(proxyAdminOwner);
        LOCK = ILock(lock);
        LOCK.isLocked(); // Aims to verify the given address follows ILock interface
    }

    function call(address to, uint256 value, bytes calldata data) external payable onlyOwner returns (bytes memory) {
        bytes4 selector = bytes4(data);
        if (LOCK.isLocked()) {
            // While the Proxy Admin is locked it:
            // - Cannot change Proxy Admin in the Proxy, only in the ProxyAdmin contract itself
            require(selector != BeaconProxy.proxy__changeProxyAdmin.selector, Errors.Locked());
            // - Cannot change the Beacon in the Proxy
            require(selector != BeaconProxy.proxy__setBeacon.selector, Errors.Locked());
            // - Cannot change the implementation in the Proxy
            require(selector != BeaconProxy.proxy__setImplementation.selector, Errors.Locked());
            // - Cannot trigger an upgrade in the Proxy
            require(selector != BeaconProxy.proxy__triggerUpgradeToVersion.selector, Errors.Locked());
            require(selector != BeaconProxy.proxy__triggerUpgrade.selector, Errors.Locked());
            // - Cannot opt-out from auto-upgrade in the Proxy
            require(selector != BeaconProxy.proxy__optOutFromAutoUpgrade.selector, Errors.Locked());
            // - Cannot opt-in to auto-upgrade in the Proxy
            require(selector != BeaconProxy.proxy__optInToAutoUpgrade.selector, Errors.Locked());
        }
        return to.handledsafecall(value, data);
    }
}
