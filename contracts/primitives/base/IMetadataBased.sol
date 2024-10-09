// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadataBased {
    function getMetadataURI() external view returns (string memory);
    function setMetadataURI(string memory metadata) external;
}
