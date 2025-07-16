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
        require(msg.sender == IOwnable(to).owner(), Errors.InvalidMsgSender());
        bytes4 selector = bytes4(data[:4]);

        // Require the contract to be unlocked to do anything at all
        require(LOCK.isLocked(to) == false, Errors.Locked());

        // You can only call the following functions of the BeaconProxy:
        require(
            selector == BeaconProxy.proxy__changeProxyAdmin.selector || selector == BeaconProxy.proxy__setBeacon.selector
                || selector == BeaconProxy.proxy__setImplementation.selector
                || selector == BeaconProxy.proxy__triggerUpgrade.selector
                || selector == BeaconProxy.proxy__triggerUpgradeToVersion.selector
                || selector == BeaconProxy.proxy__optOutFromAutoUpgrade.selector
                || selector == BeaconProxy.proxy__optInToAutoUpgrade.selector,
            Errors.NotAllowed()
        );
        bytes memory returnData = to.handledsafecall(value, data);
        // Require the owner to not be altered by the executed transaction
        require(IOwnable(to).owner() == msg.sender, Errors.UnexpectedValue());
        return returnData;
    }
}
