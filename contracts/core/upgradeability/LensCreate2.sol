// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";
import {Errors} from "contracts/core/types/Errors.sol";

// If using the [0] nonce of 0xfe4Ad59637Cab6A5AbAEe896D3d01dA67f418e76 deployer:
address constant LENS_CREATE_2_ADDRESS = 0x52AF9CF29976C310E3DE03C509E108edB6edb8c0;

contract FixedImplementationContract {}

interface ILensCreate2 {
    function getAddress(bytes32 salt) external view returns (address);

    function createTransparentUpgradeableProxy(
        bytes32 salt,
        address implementation,
        address proxyAdmin,
        bytes calldata initializerCall,
        address expectedAddress
    ) external returns (address);
}

contract LensCreate2 is ILensCreate2, Ownable {
    address private immutable _FIXED_IMPLEMENTATION;
    bytes32 private immutable _PROXY_BYTECODE_HASH;
    bytes32 private immutable _SENDER_BYTES;
    bytes32 private immutable _CREATE2_PREFIX;
    bytes32 private immutable _CONSTRUCTOR_ARGS_HASH;

    constructor(address owner) {
        _FIXED_IMPLEMENTATION = address(new FixedImplementationContract());
        address proxy = address(new TransparentUpgradeableProxy(FIXED_IMPLEMENTATION(), address(this), ""));
        bytes32 bytecodeHash;
        assembly {
            bytecodeHash := extcodehash(proxy)
        }
        _PROXY_BYTECODE_HASH = bytecodeHash;
        _CREATE2_PREFIX = keccak256("zksyncCreate2");
        _SENDER_BYTES = bytes32(uint256(uint160(address(this))));
        _CONSTRUCTOR_ARGS_HASH = keccak256(abi.encode(FIXED_IMPLEMENTATION(), address(this), ""));
        _transferOwnership(owner);
    }

    function getAddress(bytes32 salt) external view override returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        bytes.concat(
                            CREATE2_PREFIX(), SENDER_BYTES(), salt, PROXY_BYTECODE_HASH(), CONSTRUCTOR_ARGS_HASH()
                        )
                    )
                )
            )
        );
    }

    function createTransparentUpgradeableProxy(
        bytes32 salt,
        address implementation,
        address proxyAdmin,
        bytes calldata initializerCall,
        address expectedAddress
    ) external override onlyOwner returns (address) {
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(
            address(new TransparentUpgradeableProxy{salt: salt}(FIXED_IMPLEMENTATION(), address(this), ""))
        );
        require(expectedAddress == address(0) || expectedAddress == address(proxy), Errors.UnexpectedValue());
        if (initializerCall.length > 0) {
            proxy.upgradeToAndCall(implementation, initializerCall);
        } else {
            proxy.upgradeTo(implementation);
        }
        proxy.changeAdmin(proxyAdmin);
        return address(proxy);
    }

    // TODO: These are only really needed for etch to work...

    function FIXED_IMPLEMENTATION() public view virtual returns (address) {
        return _FIXED_IMPLEMENTATION;
    }

    function PROXY_BYTECODE_HASH() public view virtual returns (bytes32) {
        return _PROXY_BYTECODE_HASH;
    }

    function SENDER_BYTES() public view virtual returns (bytes32) {
        return _SENDER_BYTES;
    }

    function CREATE2_PREFIX() public view virtual returns (bytes32) {
        return _CREATE2_PREFIX;
    }

    function CONSTRUCTOR_ARGS_HASH() public view virtual returns (bytes32) {
        return _CONSTRUCTOR_ARGS_HASH;
    }
}
