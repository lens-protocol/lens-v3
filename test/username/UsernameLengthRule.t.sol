// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {UsernameLengthRule} from "../../contracts/primitives/username/Rules/UsernameLengthRule.sol";
import {OwnerOnlyAccessControl} from "../../contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UsernameLengthRuleTest is Test {
    UsernameLengthRule public rule;
    OwnerOnlyAccessControl public ownerOnlyAccessControl;

    address public owner = address(1);

    function setUp() public {
        vm.startPrank(owner);
        // Setup proxy contract to delegate calls to the UsernameLengthRule contract
        UsernameLengthRule usernameLengthRuleImplementation = new UsernameLengthRule();
        ERC1967Proxy usernameLengthRuleProxy = new ERC1967Proxy(address(usernameLengthRuleImplementation), "");
        rule = UsernameLengthRule(address(usernameLengthRuleProxy));
        ownerOnlyAccessControl = new OwnerOnlyAccessControl(owner);
        vm.stopPrank();
    }

    function testProcessRegisteringValidLength() public {
        bytes memory data = abi.encode(3, 10);
        rule.configure(data);

        rule.processRegistering(address(this), address(this), "user", "");
        rule.processRegistering(address(this), address(this), "username", "");
    }

    function testProcessRegisteringUnlimitedMaxLength() public {
        bytes memory data = abi.encode(3, 0);
        rule.configure(data);

        rule.processRegistering(address(this), address(this), "verylongusername", "");
    }

    function testCannotConfigureInvalidMinLength() public {
        bytes memory data = abi.encode(0, 10);
        vm.expectRevert();
        rule.configure(data);
    }

    function testCannotConfigureInvalidMaxLength() public {
        bytes memory data = abi.encode(5, 3);
        vm.expectRevert();
        rule.configure(data);
    }

    function testCannotProcessRegisteringTooShort() public {
        bytes memory data = abi.encode(3, 10);
        rule.configure(data);

        vm.expectRevert();
        rule.processRegistering(address(this), address(this), "us", "");
    }

    function testCannotProcessRegisteringTooLong() public {
        bytes memory data = abi.encode(3, 10);
        rule.configure(data);

        vm.expectRevert();
        rule.processRegistering(address(this), address(this), "verylongusername", "");
    }
}
