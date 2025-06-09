// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {IDependentLock} from "contracts/core/interfaces/IDependentLock.sol";
import {IOwnable} from "contracts/core/interfaces/IOwnable.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {CallLib} from "contracts/core/libraries/CallLib.sol";
import {Errors} from "contracts/core/types/Errors.sol";

/**
 * Contract to ensure that the proxy admin is synced with the underlying contract's owner.
 *
 * Given that fetches the owner from the contract, it does not work with TransparentUpgradeableProxy, as in those type
 * of proxies, the proxy admin cannot fallback to the proxy target.
 */
contract ProxyAdminForOwnable {
    using CallLib for address;

    IDependentLock immutable LOCK;

    constructor(address lock) {
        LOCK = IDependentLock(lock);
        LOCK.isLocked(address(this)); // Aims to verify the given address follows IDependentLock interface
    }

    function call(address to, uint256 value, bytes calldata data) external payable returns (bytes memory) {
        bytes4 selector = bytes4(data);
        if (LOCK.isLocked(to)) {
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
        // Require the msg.sender to match the owner
        require(msg.sender == IOwnable(to).owner(), Errors.InvalidMsgSender());
        bytes memory returnData = to.handledsafecall(value, data);
        // Require the owner to not be altered by the executed transaction
        require(IOwnable(to).owner() == msg.sender, Errors.UnexpectedValue());
        return returnData;
    }
}
