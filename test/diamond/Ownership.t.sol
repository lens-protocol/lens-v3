pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {Ownership} from "../../contracts/diamond/Ownership.sol";

contract OwnershipTest is Test {
    Ownership ownership;
    address owner = address(1);
    address newOwner = address(2);

    function setUp() public {
        ownership = new Ownership(owner);
    }

    function testInitialOwner() public {
        assertEq(ownership.getOwner(), owner);
    }

    function testTransferOwnership() public {
        vm.prank(owner);
        ownership.transferOwnership(newOwner);

        assertEq(ownership.getOwner(), owner);

        vm.prank(newOwner);
        ownership.confirmOwnershipTransfer();

        assertEq(ownership.getOwner(), owner); // Owner should not change

        vm.prank(owner);
        ownership.confirmOwnershipTransfer();

        assertEq(ownership.getOwner(), newOwner); // Now the owner should change
    }

    function testFailTransferOwnershipNonOwner() public {
        vm.prank(newOwner);
        ownership.transferOwnership(newOwner);
    }
}
