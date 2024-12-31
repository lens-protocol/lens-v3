// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

interface ILock {
    function isRestricted() external view returns (bool);
}

contract ProxyAdmin {
    ILock immutable LOCK;
    address internal _proxyAdmin;

    constructor(address proxyAdmin, address lock) {
        _proxyAdmin = proxyAdmin;
        LOCK = ILock(lock);
    }

    function ProxyAdmin__changeProxyAdmin(
        address proxyAdmin
    ) external {
        require(msg.sender == _proxyAdmin);
        _proxyAdmin = proxyAdmin;
        // Event
    }

    function ProxyAdmin__call(address to, uint256 value, bytes calldata data) external payable returns (bytes memory) {
        bytes4 selector = bytes4(data[0]);
        if (LOCK.isRestricted()) {
            // While the Proxy Admin is restricted:
            // - Cannot change Proxy Admin in the Proxy, only in the ProxyAdmin contract itself
            require(selector != bytes4(keccak256("changeProxyAdmin(address)")));
            // - Cannot change the Beacon in the Proxy
            require(selector != bytes4(keccak256("setBeacon(address")));
            // - Cannot change the implementation in the Proxy
            require(selector != bytes4(keccak256("setImplementation(address)")));
            // - Cannot trigger an upgrade in the Proxy for specific version
            require(selector != bytes4(keccak256("triggerUpgrade(uint256)")));
            // - Cannot opt-out from auto-upgrade in the Proxy
            require(selector != bytes4(keccak256("optOutFromAutoUpgrade()")));
            // - Cannot opt-in from auto-upgrade in the Proxy
            require(selector != bytes4(keccak256("optInFromAutoUpgrade()")));
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
