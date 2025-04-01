// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

struct LensFeesData {
    address treasuryAddress;
    uint16 treasuryFeeBps;
}

interface ILensFees {
    function getTreasuryAddress() external view returns (address);

    function getTreasuryFeeBps() external view returns (uint16);

    function getLensFeesData() external view returns (LensFeesData memory);
}

contract LensFees is ILensFees {
    address internal immutable LENS_TREASURY_ADDRESS;
    uint16 internal immutable LENS_TREASURY_FEE_BPS;

    constructor(address treasuryAddress, uint16 treasuryFeeBps) {
        LENS_TREASURY_ADDRESS = treasuryAddress;
        LENS_TREASURY_FEE_BPS = treasuryFeeBps;
    }

    function getTreasuryAddress() external view override returns (address) {
        return LENS_TREASURY_ADDRESS;
    }

    function getTreasuryFeeBps() external view override returns (uint16) {
        return LENS_TREASURY_FEE_BPS;
    }

    function getLensFeesData() external view override returns (LensFeesData memory) {
        return LensFeesData(LENS_TREASURY_ADDRESS, LENS_TREASURY_FEE_BPS);
    }
}
