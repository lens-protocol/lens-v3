// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {ILock} from "contracts/core/interfaces/ILock.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";

contract ProxyAdmin {
    ILock immutable LOCK;
    address internal _proxyAdmin;

    constructor(address proxyAdmin, address lock) {
        _proxyAdmin = proxyAdmin;
        LOCK = ILock(lock);
    }

    function ProxyAdmin__changeProxyAdmin(address proxyAdmin) external {
        require(msg.sender == _proxyAdmin);
        _proxyAdmin = proxyAdmin;
        // Event
    }

    function ProxyAdmin__call(address to, uint256 value, bytes calldata data) external payable returns (bytes memory) {
        bytes4 selector = bytes4(data[0]);
        if (LOCK.isRestricted()) {
            // While the Proxy Admin is restricted:
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
        (bool success, bytes memory ret) = to.call{value: value}(data);
        if (!success) {
            assembly {
                // Equivalent to reverting with the returned error selector if the length is not zero.
                let length := mload(ret)
                if iszero(iszero(length)) { revert(add(ret, 32), length) }
            }
        }
        return ret;
    }

    fallback() external payable {
        revert();
    }

    receive() external payable {
        revert();
    }
}
