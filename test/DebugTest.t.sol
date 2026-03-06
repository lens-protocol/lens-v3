// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "./helpers/TypeHelpers.sol";
import {BaseDeployments} from "test/helpers/BaseDeployments.sol";
import {UsernamePricePerLengthNamespaceRule} from "contracts/rules/namespace/UsernamePricePerLengthNamespaceRule.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {Namespace} from "contracts/core/primitives/namespace/Namespace.sol";
import {SourceStamp} from "contracts/core/types/Types.sol";
import {NATIVE_TOKEN} from "contracts/core/types/Constants.sol";
import {Beacon} from "contracts/core/upgradeability/Beacon.sol";

struct PaymentConfiguration {
    address token;
    uint256 amount;
    address recipient;
}

// This contraption can be used as a template for debugging on-chain transactions.

contract DebugTest is Test, BaseDeployments {
    function setUp() public override onlyFork {
        // super.setUp();
        // address usernamePricePerLengthNamespaceRuleImpl = address(new UsernamePricePerLengthNamespaceRule());

        // ITransparentUpgradeableProxy usernamePricePerLengthNamespaceRule =
        //     ITransparentUpgradeableProxy(payable(0x4aBdf719Bc6659e91233c62D4d08D6F4229989e8));

        // vm.prank(rulesProxyOwner);
        // usernamePricePerLengthNamespaceRule.upgradeTo(usernamePricePerLengthNamespaceRuleImpl);

        // address namespaceImpl = address(new Namespace());
        // Beacon beacon = Beacon(0x1a0cF59005eDb06F922B5E169a90E4DC5c91e988);

        // vm.startPrank(beaconOwner);
        // beacon.setImplementationForVersion(1, namespaceImpl);
        // beacon.setDefaultVersion(1);
        // vm.stopPrank();
    }

    // function testDebug1() public onlyFork {
    //     console.log("Starting testDebug");
    //     address msgSender = 0x66E13392d931d71fbb623A723A314094C018C3C4;
    //     address to = 0x609F83A57782D4a703E095F828053dAC1ad66Bd6;
    //     uint256 msgValue;
    //     bytes memory txCalldata =
    //         hex"1a0e518000000000000000000000000087939cc0ef01f1e082ca0ad63ff71105e3a6911b00000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000002c000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000000e743137353033313732373530333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020edc03eff258927169d8466a6d671afad7cb0b69c2ad73f480eab23a233329cfc000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c75a89145d765c396fd75cbd16380eb184bd2ca700000000000000000000000087939cc0ef01f1e082ca0ad63ff71105e3a6911b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

    //     vm.prank(msgSender);
    //     (bool success, bytes memory returnData) = to.call{value: msgValue}(txCalldata);
    //     console.log("success", success);
    //     console.logBytes(returnData);
    // }

    // function testDebug2() public onlyFork {
    //     console.log("Starting testDebug2");
    //     address msgSender = 0x00A58BA275E6BFC004E2bf9be121a15a2c543e71;

    //     Namespace namespace = Namespace(0xce39182cf585fAbeaf7Fb4cf5Fc5e1d7756c7A75);

    //     SourceStamp memory sourceStamp = SourceStamp({
    //         source: 0xC75A89145d765c396fd75CbD16380Eb184Bd2ca7,
    //         originalMsgSender: 0x587a59328D0E456832FCcc0eF31ef3b4928B0FF5,
    //         validator: 0x0000000000000000000000000000000000000000,
    //         nonce: 0,
    //         deadline: 0,
    //         signature: ""
    //     });

    //     vm.prank(msgSender);
    //     namespace.createAndAssignUsername({
    //         account: 0x587a59328D0E456832FCcc0eF31ef3b4928B0FF5,
    //         username: "t1750276823760",
    //         customParams: _toKeyValueArray(
    //             KeyValue(0xedc03eff258927169d8466a6d671afad7cb0b69c2ad73f480eab23a233329cfc, abi.encode(sourceStamp))
    //         ),
    //         unassigningProcessingParams: _emptyRuleProcessingParamsArray(),
    //         creationProcessingParams: _toRuleProcessingParamsArray(
    //             RuleProcessingParams({
    //                 ruleAddress: 0x4aBdf719Bc6659e91233c62D4d08D6F4229989e8,
    //                 configSalt: bytes32(uint256(4)),
    //                 ruleParams: _toKeyValueArray(
    //                     KeyValue(
    //                         0x1d614931e4da442dfded7a7b2023927603d40081577686bb6fd4debb2fd73fc0,
    //                         abi.encode(
    //                             PaymentConfiguration({
    //                                 token: NATIVE_TOKEN,
    //                                 amount: 100000000000000,
    //                                 recipient: 0x00A58BA275E6BFC004E2bf9be121a15a2c543e71
    //                             })
    //                         )
    //                     ),
    //                     KeyValue(
    //                         0x183a1b7fdb9626f5ae4e8cac88ee13cc03b29800d2690f61e2a2566f76d8773f,
    //                         abi.encode(RecipientData({recipient: 0x0000000000000000000000000000000000000020, splitBps: 0}))
    //                     )
    //                 )
    //             })
    //         ),
    //         assigningProcessingParams: _emptyRuleProcessingParamsArray(),
    //         extraData: _emptyKeyValueArray()
    //     });
    // }

    // function testDebug3() public onlyFork {
    //     console.log("Starting testDebug3");
    //     address msgSender = 0x66E13392d931d71fbb623A723A314094C018C3C4;

    //     Namespace namespace = Namespace(0x609F83A57782D4a703E095F828053dAC1ad66Bd6);

    //     SourceStamp memory sourceStamp = SourceStamp({
    //         source: 0xC75A89145d765c396fd75CbD16380Eb184Bd2ca7,
    //         originalMsgSender: 0x87939cC0ef01F1e082cA0aD63FF71105e3A6911b,
    //         validator: 0x0000000000000000000000000000000000000000,
    //         nonce: 0,
    //         deadline: 0,
    //         signature: ""
    //     });

    //     vm.prank(msgSender);
    //     namespace.createAndAssignUsername({
    //         account: 0x87939cC0ef01F1e082cA0aD63FF71105e3A6911b,
    //         username: "t1750317275033",
    //         customParams: _toKeyValueArray(
    //             KeyValue(0xedc03eff258927169d8466a6d671afad7cb0b69c2ad73f480eab23a233329cfc, abi.encode(sourceStamp))
    //         ),
    //         unassigningProcessingParams: _emptyRuleProcessingParamsArray(),
    //         creationProcessingParams: _emptyRuleProcessingParamsArray(),
    //         assigningProcessingParams: _emptyRuleProcessingParamsArray(),
    //         extraData: _emptyKeyValueArray()
    //     });
    // }
}
