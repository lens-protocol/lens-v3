// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "test/helpers/TypeHelpers.sol";
import {RoleBasedAccessControl} from "@core/access/RoleBasedAccessControl.sol";
import {Access} from "@core/interfaces/IRoleBasedAccessControl.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {Errors} from "@core/types/Errors.sol";

contract RoleBasedAccessControlSymbolicTest is Test {
    address owner;
    RoleBasedAccessControl accessControl;
    uint256 OWNER_ROLE_ID;

    function setUp() public virtual {
        owner = address(this);
        accessControl = new RoleBasedAccessControl(owner);
        OWNER_ROLE_ID = uint256(keccak256("lens.role.Owner"));
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function check_ConstructorSetsProperOwner() public view {
        assertTrue(OWNER_ROLE_ID == uint256(keccak256("lens.role.Owner")));
        assertTrue(accessControl.hasRole({account: owner, roleId: OWNER_ROLE_ID}));
    }

    function check_OwnerHasAccessToEverything(address contractAddress, uint256 permissionId) public view {
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);

        assertTrue(accessControl.hasRole({account: owner, roleId: OWNER_ROLE_ID}));
        assertTrue(
            accessControl.getAccess({roleId: OWNER_ROLE_ID, contractAddress: address(0), permissionId: 0})
                == Access.GRANTED
        );
        assertTrue(
            accessControl.hasAccess({account: owner, contractAddress: contractAddress, permissionId: permissionId})
        );
    }

    function check_CanChangeAccessControl_IfOwner(address newAccessControl) public view {
        assertTrue(accessControl.canChangeAccessControl(owner, newAccessControl));
    }

    function check_Cannot_CanChangeAccessControl_IfNotOwner(address nonOwnerAccount, address contractAddress)
        public
        view
    {
        vm.assume(accessControl.hasRole(nonOwnerAccount, OWNER_ROLE_ID) == false);
        assertFalse(
            IAccessControl(accessControl).canChangeAccessControl({
                account: nonOwnerAccount,
                contractAddress: contractAddress
            })
        );
    }

    function check_CanGrantRole_IfOwner(uint256 roleId, address account) public {
        vm.assume(roleId != OWNER_ROLE_ID);

        assertFalse(accessControl.hasRole({account: account, roleId: roleId}));

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(accessControl.hasRole({account: account, roleId: roleId}));
    }

    function check_CanRevokeRole_IfOwner(uint256 roleId, address account) public {
        vm.assume(roleId != OWNER_ROLE_ID);

        accessControl.grantRole({account: account, roleId: roleId});
        assertTrue(accessControl.hasRole({account: account, roleId: roleId}));

        accessControl.revokeRole({account: account, roleId: roleId});

        assertFalse(accessControl.hasRole({account: account, roleId: roleId}));
    }

    function check_TransferOwnership_IfOwner(address newOwner) public {
        vm.assume(owner != newOwner);

        assertTrue(accessControl.hasRole(owner, OWNER_ROLE_ID));
        assertFalse(accessControl.hasRole(newOwner, OWNER_ROLE_ID));

        accessControl.transferOwnership({newOwner: newOwner});

        assertFalse(accessControl.hasRole(owner, OWNER_ROLE_ID));
        assertTrue(accessControl.hasRole(newOwner, OWNER_ROLE_ID));
    }

    function check_SetAccess_AnyAddress_AnyPermission(
        address account,
        uint256 roleId,
        address contractAddress,
        uint256 permissionId
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);

        accessControl.setAccess({roleId: roleId, contractAddress: address(0), permissionId: 0, access: Access.GRANTED});

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(
            accessControl.hasAccess({account: account, contractAddress: contractAddress, permissionId: permissionId})
        );
    }

    function check_SetAccess_AnyAddress_SpecificPermission(
        address account,
        uint256 roleId,
        address contractAddress,
        uint256 permissionId
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);

        accessControl.setAccess({
            roleId: roleId,
            contractAddress: address(0),
            permissionId: permissionId,
            access: Access.GRANTED
        });

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(
            accessControl.hasAccess({account: account, contractAddress: contractAddress, permissionId: permissionId})
        );
    }

    function check_SetAccess_SpecificAddress_AnyPermission(
        address account,
        uint256 roleId,
        address contractAddress,
        uint256 permissionId
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);

        accessControl.setAccess({
            roleId: roleId,
            contractAddress: contractAddress,
            permissionId: 0,
            access: Access.GRANTED
        });

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(
            accessControl.hasAccess({account: account, contractAddress: contractAddress, permissionId: permissionId})
        );
    }

    function check_SetAccess_SpecificAddress_SpecificPermission(
        address account,
        uint256 roleId,
        address contractAddress,
        uint256 permissionId
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);

        accessControl.setAccess({
            roleId: roleId,
            contractAddress: contractAddress,
            permissionId: permissionId,
            access: Access.GRANTED
        });

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(
            accessControl.hasAccess({account: account, contractAddress: contractAddress, permissionId: permissionId})
        );
    }

    function check_SetAccess_DenySpecificPermission_ForAllAddress_ExceptOne(
        address account,
        uint256 roleId,
        address contractAddress,
        uint256 permissionId,
        address anotherContractAddress
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);
        vm.assume(anotherContractAddress != address(0) && anotherContractAddress != contractAddress);

        accessControl.setAccess({
            roleId: roleId,
            contractAddress: address(0),
            permissionId: permissionId,
            access: Access.DENIED
        });
        accessControl.setAccess({
            roleId: roleId,
            contractAddress: contractAddress,
            permissionId: permissionId,
            access: Access.GRANTED
        });

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(
            accessControl.hasAccess({account: account, contractAddress: contractAddress, permissionId: permissionId})
        );
        assertFalse(
            accessControl.hasAccess({
                account: account,
                contractAddress: anotherContractAddress,
                permissionId: permissionId
            })
        );
    }

    function check_SetAccess_GrantSpecificPermission_ForAllAddress_ExceptOne(
        address account,
        uint256 roleId,
        address contractAddress,
        uint256 permissionId,
        address anotherContractAddress
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);
        vm.assume(anotherContractAddress != address(0) && anotherContractAddress != contractAddress);

        accessControl.setAccess({
            roleId: roleId,
            contractAddress: address(0),
            permissionId: permissionId,
            access: Access.GRANTED
        });
        accessControl.setAccess({
            roleId: roleId,
            contractAddress: contractAddress,
            permissionId: permissionId,
            access: Access.DENIED
        });

        accessControl.grantRole({account: account, roleId: roleId});

        assertFalse(
            accessControl.hasAccess({account: account, contractAddress: contractAddress, permissionId: permissionId})
        );
        assertTrue(
            accessControl.hasAccess({
                account: account,
                contractAddress: anotherContractAddress,
                permissionId: permissionId
            })
        );
    }

    function check_SetAccess_DenyAllPermissions_ExceptOne_InAllAddresses(
        address account,
        uint256 roleId,
        uint256 grantedPermissionId,
        address contractAddress,
        uint256 anotherPermissionId
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(grantedPermissionId != 0);
        vm.assume(contractAddress != address(0));
        vm.assume(anotherPermissionId != 0 && anotherPermissionId != grantedPermissionId);

        accessControl.setAccess({roleId: roleId, contractAddress: address(0), permissionId: 0, access: Access.DENIED});
        accessControl.setAccess({
            roleId: roleId,
            contractAddress: address(0),
            permissionId: grantedPermissionId,
            access: Access.GRANTED
        });

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(
            accessControl.hasAccess({
                account: account,
                contractAddress: contractAddress,
                permissionId: grantedPermissionId
            })
        );
        assertFalse(
            accessControl.hasAccess({
                account: account,
                contractAddress: contractAddress,
                permissionId: anotherPermissionId
            })
        );
    }

    function check_SetAccess_DenyAllPermissions_ExceptOne_ForSpecificAddress(
        address account,
        uint256 roleId,
        address contractAddress,
        uint256 grantedPermissionId,
        address anotherContractAddress,
        uint256 anotherPermissionId
    ) public {
        vm.assume(account != owner);
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(contractAddress != address(0));
        vm.assume(grantedPermissionId != 0);
        vm.assume(anotherContractAddress != address(0) && anotherContractAddress != contractAddress);
        vm.assume(anotherPermissionId != 0 && anotherPermissionId != grantedPermissionId);

        accessControl.setAccess({
            roleId: roleId,
            contractAddress: contractAddress,
            permissionId: 0,
            access: Access.DENIED
        });
        accessControl.setAccess({
            roleId: roleId,
            contractAddress: contractAddress,
            permissionId: grantedPermissionId,
            access: Access.GRANTED
        });

        accessControl.grantRole({account: account, roleId: roleId});

        assertTrue(
            accessControl.hasAccess({
                account: account,
                contractAddress: contractAddress,
                permissionId: grantedPermissionId
            })
        );
        assertFalse(
            accessControl.hasAccess({
                account: account,
                contractAddress: contractAddress,
                permissionId: anotherPermissionId
            })
        );
        assertFalse(
            accessControl.hasAccess({
                account: account,
                contractAddress: anotherContractAddress,
                permissionId: anotherPermissionId
            })
        );
        assertFalse(
            accessControl.hasAccess({
                account: account,
                contractAddress: anotherContractAddress,
                permissionId: grantedPermissionId
            })
        );
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _validAccess(uint8 access) internal pure returns (bool) {
        return access == uint8(Access.DENIED) || access == uint8(Access.GRANTED) || access == uint8(Access.UNDEFINED);
    }
}
