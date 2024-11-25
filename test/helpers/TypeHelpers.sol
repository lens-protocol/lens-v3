// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    RuleExecutionData,
    RuleChange,
    SourceStamp,
    RuleConfiguration,
    DataElement
} from "../../contracts/core/types/Types.sol";

function _emptyExtraData() pure returns (DataElement[] memory) {
    return new DataElement[](0);
}

function _emptyRuleChangeArray() pure returns (RuleChange[] memory) {
    return new RuleChange[](0);
}

function _emptyRuleConfigurationArray() pure returns (RuleConfiguration[] memory) {
    return new RuleConfiguration[](0);
}

function _emptyExecutionData() pure returns (RuleExecutionData memory) {
    return RuleExecutionData(_emptyBytesArray(), _emptyBytesArray());
}

function _emptySourceStamp() pure returns (SourceStamp memory) {
    return SourceStamp(address(0), 0, 0, "");
}

function _emptyUint256Array() pure returns (uint256[] memory) {
    uint256[] memory ret = new uint256[](0);
    return ret;
}

function _toUint256Array(uint256 n) pure returns (uint256[] memory) {
    uint256[] memory ret = new uint256[](1);
    ret[0] = n;
    return ret;
}

function _toUint256Array(uint256 n0, uint256 n1) pure returns (uint256[] memory) {
    uint256[] memory ret = new uint256[](2);
    ret[0] = n0;
    ret[1] = n1;
    return ret;
}

function _emptyBytesArray() pure returns (bytes[] memory) {
    bytes[] memory ret = new bytes[](0);
    return ret;
}

function _emptyBytes32Array() pure returns (bytes32[] memory) {
    return new bytes32[](0);
}

function _toBytesArray(bytes memory b) pure returns (bytes[] memory) {
    bytes[] memory ret = new bytes[](1);
    ret[0] = b;
    return ret;
}

function _toBytesArray(bytes memory b0, bytes memory b1) pure returns (bytes[] memory) {
    bytes[] memory ret = new bytes[](2);
    ret[0] = b0;
    ret[1] = b1;
    return ret;
}

function _toBoolArray(bool b) pure returns (bool[] memory) {
    bool[] memory ret = new bool[](1);
    ret[0] = b;
    return ret;
}

function _toBoolArray(bool b0, bool b1) pure returns (bool[] memory) {
    bool[] memory ret = new bool[](2);
    ret[0] = b0;
    ret[1] = b1;
    return ret;
}

function _emptyAddressArray() pure returns (address[] memory) {
    address[] memory ret = new address[](0);
    return ret;
}

function _toAddressArray(address a) pure returns (address[] memory) {
    address[] memory ret = new address[](1);
    ret[0] = a;
    return ret;
}

function _toAddressArray(address a0, address a1) pure returns (address[] memory) {
    address[] memory ret = new address[](2);
    ret[0] = a0;
    ret[1] = a1;
    return ret;
}
