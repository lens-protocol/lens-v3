// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRule {
    bytes4 constant DEFAULT_CONFIGURE_SELECTOR = bytes4(keccak256("configure(bytes,bytes)"));
    bytes4 constant DEFAULT_PROCESS_SELECTOR = bytes4(keccak256("process(bytes,bytes)"));

    event Lens_RuleConfigured(
        address indexed primitiveAddress, bytes4 indexed selector, bytes primitiveParams, bytes userParams
    );

    event Lens_RuleProcessed(
        address indexed primitiveAddress, bytes4 indexed selector, bytes primitiveParams, bytes userParams
    );

    function configure(bytes4 selector, bytes memory primitiveParams, bytes calldata userParams) external;

    function process(bytes4 selector, bytes memory primitiveParams, bytes calldata userParams)
        external
        returns (bool isImplemented);
}
