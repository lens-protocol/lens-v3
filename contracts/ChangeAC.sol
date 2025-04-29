// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {AccessControlled} from "contracts/core/access/AccessControlled.sol";
import {AccessControlFactory} from "contracts/extensions/factories/AccessControlFactory.sol";
import {IAccessControl} from "contracts/core/interfaces/IAccessControl.sol";
import {Ownable} from "contracts/core/access/Ownable.sol";

contract ChangeAC {
    address immutable ACCESS_CONTROL_FACTORY;

    /// @custom:keccak lens.contract.AccessControl.OwnerAdminOnlyAccessControl
    bytes32 constant OWNER_ADMIN_ONLY_CONTRACT_TYPE = 0x366c180b93c016d94aa781dd984842068840b0dc26dec0c4bf64de7c26ee02bb;

    constructor(address accessControlFactory) {
        ACCESS_CONTROL_FACTORY = accessControlFactory;
    }

    function changeACs(address[] memory accessControlledContracts, address newOwner) public {
        for (uint256 i = 0; i < accessControlledContracts.length; i++) {
            address accessControlledContract = accessControlledContracts[i];

            address newAccessControl = address(
                AccessControlFactory(ACCESS_CONTROL_FACTORY).deployOwnerAdminOnlyAccessControl(
                    newOwner, new address[](0)
                )
            );
            AccessControlled(accessControlledContract).setAccessControl(IAccessControl(newAccessControl));

            require(
                AccessControlled(accessControlledContract).getAccessControl() == IAccessControl(newAccessControl),
                "Access control not set correctly"
            );
            require(Ownable(newAccessControl).owner() == newOwner, "Owner not set correctly");
            require(
                IAccessControl(newAccessControl).getType() == OWNER_ADMIN_ONLY_CONTRACT_TYPE,
                "Invalid access control type"
            );
        }
    }
}
