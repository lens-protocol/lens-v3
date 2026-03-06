// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

interface IMetadataBased {
    function getMetadataURI() external view returns (string memory);
    function setMetadataURI(string memory metadata) external;
}
