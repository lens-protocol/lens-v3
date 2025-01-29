// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "test/helpers/TypeHelpers.sol";
import {OwnerAdminOnlyAccessControl} from "@extensions/access/OwnerAdminOnlyAccessControl.sol";
import {Access} from "@core/interfaces/IRoleBasedAccessControl.sol";
import {IAccessControl} from "@core/interfaces/IAccessControl.sol";
import {Errors} from "@core/types/Errors.sol";
import {Lock} from "@core/upgradeability/Lock.sol";

contract OwnerAdminOnlyAccessControlTest is Test {
    address owner;
    address admin;
    Lock lock;
    OwnerAdminOnlyAccessControl accessControl;
    uint256 OWNER_ROLE_ID;
    uint256 ADMIN_ROLE_ID;

    function setUp() public virtual {
        owner = address(this);
        lock = new Lock(address(this), true);
        accessControl = new OwnerAdminOnlyAccessControl(owner, address(lock));
        OWNER_ROLE_ID = uint256(keccak256("lens.role.Owner"));
        ADMIN_ROLE_ID = uint256(keccak256("lens.role.Admin"));
        accessControl.grantRole({account: admin, roleId: ADMIN_ROLE_ID});
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function test_ConstructorSetsProperOwner() public view {
        assertTrue(OWNER_ROLE_ID == uint256(keccak256("lens.role.Owner")));
        assertTrue(accessControl.hasRole({account: owner, roleId: OWNER_ROLE_ID}));
    }

    function test_OwnerHasAccessToEverything(address contractAddress, uint256 permissionId) public view {
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

    function test_AdminHasAccessToEverything(address contractAddress, uint256 permissionId) public view {
        vm.assume(contractAddress != address(0));
        vm.assume(permissionId != 0);

        assertTrue(accessControl.hasRole({account: admin, roleId: ADMIN_ROLE_ID}));
        assertTrue(
            accessControl.getAccess({roleId: ADMIN_ROLE_ID, contractAddress: address(0), permissionId: 0})
                == Access.GRANTED
        );
        assertTrue(
            accessControl.hasAccess({account: admin, contractAddress: contractAddress, permissionId: permissionId})
        );
    }

    function test_CanChangeAccessControl_IfOwner_And_LockUnlocked(address newAccessControl) public {
        lock.setLockStatus(false);
        assertFalse(lock.isLocked());

        assertTrue(accessControl.canChangeAccessControl(owner, newAccessControl));
    }

    function test_Cannot_ChangeAccessControl_IfOwner_But_LockLocked(address newAccessControl) public {
        lock.setLockStatus(true);
        assertTrue(lock.isLocked());

        assertFalse(accessControl.canChangeAccessControl(owner, newAccessControl));
    }

    function test_Cannot_ChangeAccessControl_IfAdminButNotOwner(address newAccessControl) public view {
        assertFalse(accessControl.hasRole({account: admin, roleId: OWNER_ROLE_ID}));
        assertTrue(accessControl.hasRole({account: admin, roleId: ADMIN_ROLE_ID}));

        assertFalse(accessControl.canChangeAccessControl(admin, newAccessControl));
    }

    function test_Cannot_CanChangeAccessControl_IfNotOwner(address nonOwnerAccount, address contractAddress)
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

    function test_Cannot_GrantNonAdminRole_EvenIfOwner(uint256 roleId, address account) public {
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(roleId != ADMIN_ROLE_ID);

        vm.expectRevert(Errors.InvalidParameter.selector);
        accessControl.grantRole({account: account, roleId: roleId});
    }

    function test_Cannot_GrantAdminRole_IfNotOwner(address nonOwnerAccount, address account) public {
        vm.assume(accessControl.hasRole(nonOwnerAccount, OWNER_ROLE_ID) == false);
        vm.assume(accessControl.hasRole(account, ADMIN_ROLE_ID) == false);

        vm.prank(nonOwnerAccount);
        vm.expectRevert(Errors.InvalidMsgSender.selector);
        accessControl.grantRole({account: account, roleId: ADMIN_ROLE_ID});

        assertFalse(accessControl.hasRole({account: account, roleId: ADMIN_ROLE_ID}));
    }

    function test_Cannot_GrantRole_IfRoleIsOwnerRole(address account) public {
        vm.expectRevert(Errors.InvalidParameter.selector);
        accessControl.grantRole({account: account, roleId: OWNER_ROLE_ID});
    }

    function test_Cannot_SetAccess_IfNotOwner(
        address msgSenderAccount,
        uint256 roleId,
        address contractAddress,
        uint256 permissionId,
        uint8 access
    ) public {
        vm.assume(roleId != OWNER_ROLE_ID);
        vm.assume(_validAccess(access));
        vm.assume(access != uint8(Access.UNDEFINED));

        vm.prank(msgSenderAccount);
        vm.expectRevert(Errors.NotImplemented.selector);
        accessControl.setAccess({
            roleId: roleId,
            contractAddress: contractAddress,
            permissionId: permissionId,
            access: Access(access)
        });
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function _validAccess(uint8 access) internal pure returns (bool) {
        return access == uint8(Access.DENIED) || access == uint8(Access.GRANTED) || access == uint8(Access.UNDEFINED);
    }
}
