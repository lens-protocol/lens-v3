// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.0;

import {ITokenURIProvider} from "./../../interfaces/ITokenURIProvider.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Events} from "./../../types/Events.sol";

contract LensUsernameTokenURIProvider is ITokenURIProvider {
    using StringsUpgradeable for uint256;

    constructor() {
        _emitLensContractDeployedEvent();
    }

    // TODO: Implement Lens Username Token URI SVGs
    function tokenURI(uint256 tokenId) external pure override returns (string memory) {
        return string.concat(
            "data:image/svg+xml;",
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800"><circle cy="400" cx="400" r="300"/><text fill="#fff" transform-origin="400 400" y="400" x="400" font-weight="bold" text-anchor="middle" font-size="80">#',
            tokenId.toString(),
            "</text></svg>"
        );
    }

    function _emitLensContractDeployedEvent() internal virtual {
        emit Events.Lens_Contract_Deployed(
            "username-token-uri-provider",
            "lens.username.token-uri-provider",
            "username-token-uri-provider",
            "lens.username.token-uri-provider"
        );
    }
}
