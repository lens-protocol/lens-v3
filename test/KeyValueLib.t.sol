// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {KeyValue} from "@core/types/Types.sol";
import {KeyValueLib} from "@core/libraries/KeyValueLib.sol";

contract KeyValueLibTest is Test {
    using KeyValueLib for KeyValue[];

    function testKeyValueConcat_1() public view {
        KeyValue[] memory start = new KeyValue[](1);
        start[0] = KeyValue(bytes32(bytes1(0x01)), abi.encode("value1"));

        KeyValue[] memory end = new KeyValue[](3);
        end[0] = KeyValue(bytes32(bytes1(0x02)), abi.encode("value2", 69));
        end[1] = KeyValue(bytes32(bytes1(0x03)), abi.encode("value3", 69, 71));
        end[2] = KeyValue(bytes32(bytes1(0x04)), abi.encode("value4", 69, 71, address(0xc0ffee)));

        KeyValueLibTest(this).concatAndAssert_1(start, end);
    }

    function concatAndAssert_1(KeyValue[] calldata start, KeyValue[] calldata end) external pure {
        KeyValue[] memory concatenatedResult = start.concat(end);

        assertEq(concatenatedResult.length, 4);

        assertEq(concatenatedResult[0].key, bytes32(bytes1(0x01)));
        assertEq(keccak256(concatenatedResult[0].value), keccak256(abi.encode("value1")));
        assertEq(concatenatedResult[1].key, bytes32(bytes1(0x02)));
        assertEq(keccak256(concatenatedResult[1].value), keccak256(abi.encode("value2", 69)));
        assertEq(concatenatedResult[2].key, bytes32(bytes1(0x03)));
        assertEq(keccak256(concatenatedResult[2].value), keccak256(abi.encode("value3", 69, 71)));
        assertEq(concatenatedResult[3].key, bytes32(bytes1(0x04)));
        assertEq(keccak256(concatenatedResult[3].value), keccak256(abi.encode("value4", 69, 71, address(0xc0ffee))));
    }

    function testKeyValueConcat_2() public view {
        KeyValue[] memory start = new KeyValue[](1);
        start[0] = KeyValue(bytes32(bytes1(0x01)), abi.encode(1));

        KeyValue[] memory end = new KeyValue[](1);
        end[0] = KeyValue(bytes32(bytes1(0x02)), abi.encode(2));

        KeyValueLibTest(this).concatAndAssert_2(start, end);
    }

    function concatAndAssert_2(KeyValue[] calldata start, KeyValue[] calldata end) external pure {
        KeyValue[] memory concatenatedResult = start.concat(end);

        assertEq(concatenatedResult.length, 2);

        console.logBytes32(start[0].key);
        console.logBytes32(end[0].key);
        console.logBytes32(concatenatedResult[0].key);
        console.logBytes32(concatenatedResult[1].key);

        assertEq(concatenatedResult[0].key, bytes32(bytes1(0x01)));
        assertEq(abi.decode(concatenatedResult[0].value, (uint256)), 1);
        assertEq(concatenatedResult[1].key, bytes32(bytes1(0x02)));
        assertEq(abi.decode(concatenatedResult[1].value, (uint256)), 2);
    }
}
