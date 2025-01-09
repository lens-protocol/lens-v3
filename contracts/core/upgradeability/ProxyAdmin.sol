// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ILock} from "contracts/core/interfaces/ILock.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";

contract ProxyAdmin is Ownable {
    using CallLib for address;

    ILock immutable LOCK;

    constructor(address proxyAdminOwner, address lock) Ownable() {
        _transferOwnership(proxyAdminOwner);
        LOCK = ILock(lock);
        LOCK.isLocked(); // Aims to verify the given address follows ILock interface
    }

    function call(address to, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
        bytes4 selector = bytes4(data[0]);
        if (LOCK.isLocked()) {
            // While the Proxy Admin is locked it:
            // - Cannot change Proxy Admin in the Proxy, only in the ProxyAdmin contract itself
            require(selector != BeaconProxy.changeProxyAdmin.selector);
            // - Cannot change the Beacon in the Proxy
            require(selector != BeaconProxy.setBeacon.selector);
            // - Cannot change the implementation in the Proxy
            require(selector != BeaconProxy.setImplementation.selector);
            // - Cannot trigger an upgrade in the Proxy
            require(selector != BeaconProxy.triggerUpgradeToVersion.selector);
            require(selector != BeaconProxy.triggerUpgrade.selector);
            // - Cannot opt-out from auto-upgrade in the Proxy
            require(selector != BeaconProxy.optOutFromAutoUpgrade.selector);
            // - Cannot opt-in to auto-upgrade in the Proxy
            require(selector != BeaconProxy.optInToAutoUpgrade.selector);
        }
        // Do the call
        (bool success, bytes memory ret) = to.safecall(value, data);
        if (!success) {
            assembly {
                // Equivalent to reverting with the returned error selector if the length is not zero.
                let length := mload(ret)
                if iszero(iszero(length)) { revert(add(ret, 32), length) }
            }
        }
        return ret;
    }
}
