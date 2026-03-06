// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

contract ZkTester {
    function isZkEvm() public view returns (bool) {
        return block.coinbase == address(0x8001);
    }
}

contract ZkTest is Test {
    function isZkEvm() public returns (bool) {
        ZkTester zkTester = new ZkTester();
        return zkTester.isZkEvm();
    }

    modifier onlyZkEvm() {
        vm.skip(!isZkEvm());
        _;
    }

    modifier onlyEvm() {
        vm.skip(isZkEvm());
        _;
    }

    modifier nonFork() {
        vm.skip(isFork());
        _;
    }

    modifier onlyFork() {
        vm.skip(!isFork());
        _;
    }
}
