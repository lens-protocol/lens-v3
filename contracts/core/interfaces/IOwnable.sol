// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

interface IOwnable {
    function transferOwnership(address newOwner) external;

    function owner() external view returns (address);
}
