// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUsernameRule {
    function configure(bytes calldata data) external;

    function processRegistering(address account, string memory username, bytes calldata data) external;

    function processUnregistering(address account, string memory username, bytes calldata data) external;
}
