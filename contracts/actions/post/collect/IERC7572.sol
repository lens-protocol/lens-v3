// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
// As appears in https://eips.ethereum.org/EIPS/eip-7572

pragma solidity ^0.8.26;

/**
 * This specification standardizes contractURI() to return contract-level metadata. This is useful for dapps and
 * offchain indexers to show rich information about a contract, such as its name, description and image, without
 * specifying it manually or individually for each dapp.
 */
interface IERC7572 {
    function contractURI() external view returns (string memory);

    event ContractURIUpdated();
}
