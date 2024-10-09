// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAccessControl} from "./IAccessControl.sol";
import {Ownership} from "./../../diamond/Ownership.sol";
import {Events} from "./../../types/Events.sol";

contract OwnerOnlyAccessControl is Ownership, IAccessControl {
    constructor(address owner) Ownership(owner) {
        emit Events.Lens_Contract_Deployed(
            "access-control", "lens.access-control.only-owner", "access-control", "lens.access-control.only-owner"
        );
    }

    function hasAccess(address account, address, /* resourceLocation */ uint256 /* resourceId */ )
        external
        view
        override
        returns (bool)
    {
        return account == _owner;
    }
}
