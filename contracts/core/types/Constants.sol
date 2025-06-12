// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

// 100.00% represented as Basis Points, each Basis Point is 0.01%
uint256 constant BPS_MAX = 10_000;

uint256 constant SELECTOR_BYTE_LENGTH = 4;

/// @custom:keccak lens.contract.ActionHub
bytes32 constant CONTRACT__ACTION_HUB = 0x914706a68d66e273351f2cd4c1f0c739a3d2d211eb45a40f548eb964a6081fef;

/// @custom:keccak lens.contract.LensFees
bytes32 constant CONTRACT__LENS_FEES = 0x5072b519d346fa8b5598f9e3ddfc010379305b352a80b2bc6c119eb92ac9a520;

/// @custom:keccak lens.contract.LensPaymentHelper
bytes32 constant CONTRACT__LENS_PAYMENT_HELPER = 0x956e17026ae4faf82a37a64911cc0dd973a36a41fd47780122d3d1a48f38400f;

address constant NATIVE_TOKEN = address(0x800A);
