// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";
import {Errors} from "contracts/core/types/Errors.sol";
import {Initializable} from "contracts/core/upgradeability/Initializable.sol";

// If using the [0] nonce of 0xfe4Ad59637Cab6A5AbAEe896D3d01dA67f418e76 deployer:
address constant LENS_CREATE_2_ADDRESS = 0x52AF9CF29976C310E3DE03C509E108edB6edb8c0;

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

contract LensCreate2 is ILensCreate2, Initializable, Ownable {
    bytes32 public immutable PROXY_BYTECODE_HASH;
    bytes32 public immutable SENDER_BYTES;
    bytes32 public immutable CREATE2_PREFIX;
    bytes32 public immutable CONSTRUCTOR_ARGS_HASH;

    constructor() {
        address proxy = address(new TransparentUpgradeableProxy(LENS_CREATE_2_ADDRESS, LENS_CREATE_2_ADDRESS, ""));
        bytes32 bytecodeHash;
        assembly {
            bytecodeHash := extcodehash(proxy)
        }
        PROXY_BYTECODE_HASH = bytecodeHash;
        CREATE2_PREFIX = keccak256("zksyncCreate2");
        SENDER_BYTES = bytes32(uint256(uint160(LENS_CREATE_2_ADDRESS)));
        CONSTRUCTOR_ARGS_HASH = keccak256(abi.encode(LENS_CREATE_2_ADDRESS, LENS_CREATE_2_ADDRESS, ""));
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        _transferOwnership(owner);
    }

    function getAddress(bytes32 salt) external view override returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        bytes.concat(CREATE2_PREFIX, SENDER_BYTES, salt, PROXY_BYTECODE_HASH, CONSTRUCTOR_ARGS_HASH)
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
            address(new TransparentUpgradeableProxy{salt: salt}(LENS_CREATE_2_ADDRESS, LENS_CREATE_2_ADDRESS, ""))
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
}
