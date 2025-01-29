// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {Errors} from "contracts/core/types/Errors.sol";
import {IOwnable} from "contracts/core/interfaces/IOwnable.sol";

abstract contract Ownable is IOwnable {
    event Lens_Ownable_OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    struct OwnableStorage {
        address owner;
    }

    /// @custom:keccak lens.storage.Ownable
    bytes32 constant STORAGE__OWNABLE = 0x29cf0539cdb8487ad7dbc33f1a5f82174ca0f44de05580c9bd8cfe649fa8c9fe;

    function $ownableStorage() private pure returns (OwnableStorage storage _storage) {
        assembly {
            _storage.slot := STORAGE__OWNABLE
        }
    }

    modifier onlyOwner() {
        require(msg.sender == $ownableStorage().owner, Errors.InvalidMsgSender());
        _;
    }

    function owner() public view virtual override returns (address) {
        return $ownableStorage().owner;
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = $ownableStorage().owner;
        $ownableStorage().owner = newOwner;
        emit Lens_Ownable_OwnershipTransferred(oldOwner, newOwner);
    }
}
