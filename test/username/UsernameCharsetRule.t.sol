// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {UsernameCharsetRule} from "../../contracts/primitives/username/Rules/UsernameCharsetRule.sol";
import {
    AddressBasedAccessControl,
    IRoleBasedAccessControl
} from "../../contracts/primitives/access-control/AddressBasedAccessControl.sol";
import {OwnerOnlyAccessControl} from "../../contracts/primitives/access-control/OwnerOnlyAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UsernameCharsetRuleTest is Test {
    UsernameCharsetRule public rule;
    AddressBasedAccessControl public addressBasedAccessControl;
    OwnerOnlyAccessControl public ownerOnlyAccessControl;

    address public owner = address(1);
    address public adminSkipCharset = address(2);
    address public adminChangeRuleAccessControl = address(3);
    address public adminConfigureRule = address(4);
    address public user1 = address(5);

    uint256 constant SKIP_CHARSET_RID = uint256(keccak256("SKIP_CHARSET"));
    uint256 constant CHANGE_RULE_ACCESS_CONTROL_RID = uint256(keccak256("CHANGE_RULE_ACCESS_CONTROL"));
    uint256 constant CONFIGURE_RULE_RID = uint256(keccak256("CONFIGURE_RULE"));

    function setUp() public {
        vm.startPrank(owner);
        ownerOnlyAccessControl = new OwnerOnlyAccessControl(owner);
        addressBasedAccessControl = new AddressBasedAccessControl(owner);
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminSkipCharset)), SKIP_CHARSET_RID, IRoleBasedAccessControl.AccessPermission.GRANTED, ""
        );
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminChangeRuleAccessControl)),
            CHANGE_RULE_ACCESS_CONTROL_RID,
            IRoleBasedAccessControl.AccessPermission.GRANTED,
            ""
        );
        addressBasedAccessControl.setGlobalAccess(
            uint256(uint160(adminConfigureRule)),
            CONFIGURE_RULE_RID,
            IRoleBasedAccessControl.AccessPermission.GRANTED,
            ""
        );
        // Setup proxy contract to delegate calls to the UsernameCharsetRule contract
        UsernameCharsetRule usernameCharsetRuleImplementation =
            new UsernameCharsetRule(OwnerOnlyAccessControl(address(0)), true);
        ERC1967Proxy usernameCharsetRuleProxy = new ERC1967Proxy(address(usernameCharsetRuleImplementation), "");
        rule = UsernameCharsetRule(address(usernameCharsetRuleProxy));
        rule.initiliaze(addressBasedAccessControl);
        vm.stopPrank();
    }

    function testChangeRulesWithCorrectRole() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: true,
            allowLatinLowercase: true,
            allowLatinUppercase: false,
            customAllowedCharset: "_",
            customDisallowedCharset: "",
            cannotStartWith: "_"
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: false,
            allowLatinLowercase: false,
            allowLatinUppercase: false,
            customAllowedCharset: "",
            customDisallowedCharset: "",
            cannotStartWith: ""
        });
        data = abi.encode(restrictions, address(0));

        vm.prank(adminConfigureRule);
        rule.configure(data);
    }

    function testCannotChangeRulesWithoutPermission() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: true,
            allowLatinLowercase: true,
            allowLatinUppercase: false,
            customAllowedCharset: "_",
            customDisallowedCharset: "",
            cannotStartWith: "_"
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: false,
            allowLatinLowercase: false,
            allowLatinUppercase: false,
            customAllowedCharset: "",
            customDisallowedCharset: "",
            cannotStartWith: ""
        });
        data = abi.encode(restrictions, address(0));

        vm.prank(user1);
        vm.expectRevert();
        rule.configure(data);
    }

    function testChangeAccessControlWithCorrectRole() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: false,
            allowLatinLowercase: false,
            allowLatinUppercase: false,
            customAllowedCharset: "",
            customDisallowedCharset: "",
            cannotStartWith: ""
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        data = abi.encode(restrictions, address(ownerOnlyAccessControl));

        vm.prank(adminChangeRuleAccessControl);
        rule.configure(data);
    }

    function testCannotChangeAccessControlWithoutPermission() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: false,
            allowLatinLowercase: false,
            allowLatinUppercase: false,
            customAllowedCharset: "",
            customDisallowedCharset: "",
            cannotStartWith: ""
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        data = abi.encode(restrictions, address(ownerOnlyAccessControl));

        vm.prank(user1);
        vm.expectRevert();
        rule.configure(data);
    }

    function testProcessRegisteringValidCharset() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: true,
            allowLatinLowercase: true,
            allowLatinUppercase: false,
            customAllowedCharset: "_",
            customDisallowedCharset: "",
            cannotStartWith: "_"
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        rule.processRegistering(address(this), address(this), "valid_username123", "");
    }

    function testCannotProcessRegisteringInvalidStartChar() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: true,
            allowLatinLowercase: true,
            allowLatinUppercase: false,
            customAllowedCharset: "_",
            customDisallowedCharset: "",
            cannotStartWith: "_"
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        vm.expectRevert("UsernameCharsetRule: Username cannot start with specified character");
        rule.processRegistering(address(this), address(this), "_invalid_start", "");
    }

    function testCannotProcessRegisteringDisallowedChar() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: true,
            allowLatinLowercase: true,
            allowLatinUppercase: false,
            customAllowedCharset: "",
            customDisallowedCharset: "$",
            cannotStartWith: ""
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        vm.expectRevert("UsernameCharsetRule: Username contains disallowed character");
        rule.processRegistering(address(this), address(this), "invalid$username", "");
    }

    function testCannotProcessRegisteringUppercaseNotAllowed() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: true,
            allowLatinLowercase: true,
            allowLatinUppercase: false,
            customAllowedCharset: "",
            customDisallowedCharset: "",
            cannotStartWith: ""
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        vm.expectRevert("UsernameCharsetRule: Username cannot contain uppercase latin characters");
        rule.processRegistering(address(this), address(this), "InvalidUppercase", "");
    }

    function testCannotProcessRegisteringCustomAllowedCharset() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: false,
            allowLatinLowercase: false,
            allowLatinUppercase: false,
            customAllowedCharset: "!@#",
            customDisallowedCharset: "",
            cannotStartWith: ""
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        rule.processRegistering(address(this), address(this), "!@#", "");

        vm.expectRevert("UsernameCharsetRule: Username cannot contain lowercase latin characters");
        rule.processRegistering(address(this), address(this), "invalid", "");
    }

    function testSkipCharsetCheck() public {
        UsernameCharsetRule.CharsetRestrictions memory restrictions = UsernameCharsetRule.CharsetRestrictions({
            allowNumeric: false,
            allowLatinLowercase: false,
            allowLatinUppercase: false,
            customAllowedCharset: "",
            customDisallowedCharset: "",
            cannotStartWith: ""
        });
        bytes memory data = abi.encode(restrictions, address(0));
        vm.prank(owner);
        rule.configure(data);

        // This should pass despite not meeting the charset restrictions
        rule.processRegistering(owner, address(this), "skipped_check123", "");
    }
}
