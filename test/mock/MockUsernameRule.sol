// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IUsernameRule} from "../../contracts/primitives/username/IUsernameRule.sol";

contract MockUsernameRule is IUsernameRule {
    function processRegistering(address, address, string memory, bytes calldata) external pure override {}
    function processUnregistering(address, address, string memory, bytes calldata) external pure override {}
    function configure(bytes calldata) external pure override {}
}
