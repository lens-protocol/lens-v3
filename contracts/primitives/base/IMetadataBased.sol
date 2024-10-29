// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadataBased {
    function getMetadataURI(address source) external view returns (string memory);
    function setMetadataURI(address source, string memory metadataURI) external;
}
