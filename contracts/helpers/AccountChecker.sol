// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {BeaconProxy as LegacyBeaconProxy} from "contracts/core/upgradeability/LegacyBeaconProxy.sol";
import {BeaconProxy} from "contracts/core/upgradeability/BeaconProxy.sol";
import {IVersionedBeacon} from "contracts/core/interfaces/IVersionedBeacon.sol";

contract AccountChecker {
    enum LensBeaconProxyType {
        UNKNOWN,
        OLD,
        NEW
    }

    IVersionedBeacon accountBeacon_Mainnet = IVersionedBeacon(0x677D8BEe894ae646Ceb1cfCe7dB16de2ef2792e5);

    function getLensBeaconProxyType(address account) public view returns (LensBeaconProxyType) {
        // EVM bytecodes hashes:
        // bytes32 oldBeaconProxyCodehash = 0x92319da5b9b4629ea296341a5a1d55915ef8031ef854dc1436125960d9d62dd9;
        // bytes32 newBeaconProxyCodehash = 0xf5bf3217f81d4490f05272940f2d57ae7095c5d57891f9dd5c41024564d9711a;

        // zkSync bytecodes hashes:
        bytes32 oldBeaconProxyCodehash = 0x01000155f66491daa99fa97065b64ee60faa4153f0b1a805839a1922c55aa130;
        bytes32 newBeaconProxyCodehash = 0x0100014dc2a18e78ebe1274413b0c4f9d5e07717bec8c863ca23b18090a28f6e;

        bytes32 bytehash = address(account).codehash;
        if (bytehash == oldBeaconProxyCodehash) return LensBeaconProxyType.OLD;
        if (bytehash == newBeaconProxyCodehash) return LensBeaconProxyType.NEW;
        return LensBeaconProxyType.UNKNOWN;
    }

    function isLensAccount(address account) public view returns (bool) {
        LensBeaconProxyType proxyType = getLensBeaconProxyType(account);
        if (proxyType == LensBeaconProxyType.OLD) {
            bool autoUpgrade = LegacyBeaconProxy(payable(account)).proxy__getAutoUpgrade();
            if (autoUpgrade == false) {
                address implementation = LegacyBeaconProxy(payable(account)).proxy__getImplementation();
                return implementation == getCanonicalImplementation();
            } else {
                address beacon = LegacyBeaconProxy(payable(account)).proxy__getBeacon();
                return beacon == address(accountBeacon_Mainnet);
            }
        }
        if (proxyType == LensBeaconProxyType.NEW) {
            address implementation = BeaconProxy(payable(account)).proxy__getEffectiveImplementation();
            return implementation == getCanonicalImplementation();
        }
        return false;
    }

    function getCanonicalImplementation() public view returns (address) {
        return accountBeacon_Mainnet.implementation();
    }
}
