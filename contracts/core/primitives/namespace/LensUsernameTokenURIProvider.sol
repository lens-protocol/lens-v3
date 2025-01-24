// SPDX-License-Identifier: UNLICENSED
// Copyright (C) 2024 Lens Labs. All Rights Reserved.
pragma solidity ^0.8.26;

import {ITokenURIProvider} from "contracts/core/interfaces/ITokenURIProvider.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {Events} from "contracts/core/types/Events.sol";
import {IERC721Namespace} from "contracts/core/interfaces/IERC721Namespace.sol";

contract LensUsernameTokenURIProvider is ITokenURIProvider {
    using StringsUpgradeable for uint256;

    constructor() {
        _emitLensContractDeployedEvent();
    }

    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        return string.concat(
            "data:image/svg+xml;",
            '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" fill="none" viewBox="0 0 512 512">',
            // Background
            '<path fill="#fff" d="M0 0h512v512H0z" style="fill:#fff;fill-opacity:1"/>',
            // Lens Logo
            '<path fill-rule="evenodd" clip-rule="evenodd" d="M91.696 55.259c2.785-2.577 6.439-4.175 10.51-4.175 9.048.002 16.377 7.34 16.377 16.393 0 7.833-7.75 14.531-9.688 16.074-9.06 7.215-20.864 11.436-33.604 11.436s-24.54-4.218-33.603-11.436c-1.927-1.545-9.689-8.255-9.689-16.076 0-9.054 7.333-16.393 16.373-16.393 4.074 0 7.73 1.598 10.515 4.175l.287-.143C59.81 46.666 66.68 40 75.29 40s15.48 6.666 16.118 15.114l.287.143z" fill="#2C2D30" fill-opacity=".3" style="fill:#2c2d30;fill:color(display-p3 .1725 .1765 .1882);fill-opacity:.3"/>',
            // Namespace & Username
            _namespaceAndUsernameTexts(tokenId),
            "</svg>"
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

    function _namespaceAndUsernameTexts(uint256 tokenId) internal view virtual returns (string memory) {
        (string memory usernameText, uint256 usernameYCoordinate, uint256 usernameAmountOfLines) = _usernameText(tokenId);
        string memory namespaceText = _namespaceText(usernameYCoordinate, usernameAmountOfLines);
        return string.concat(namespaceText, usernameText);
    }

    function _namespaceText(uint256 usernameYCoordinate, uint256 usernameAmountOfLines)
        internal
        view
        virtual
        returns (string memory)
    {
        uint256 namespaceYCoordinate;
        if (usernameAmountOfLines > 1) {
            namespaceYCoordinate = usernameYCoordinate - 49;
        } else {
            namespaceYCoordinate = usernameYCoordinate - 68;
        }
        string memory namespace = _toLowercase(IERC721Namespace(msg.sender).getNamespace());
        if (bytes(namespace).length > 18) {
            namespace = string.concat(_slice(namespace, 0, 17), "...");
        }
        return string.concat(
            '<text fill="#2C2D30" fill-opacity=".5" font-family="sans-serif" font-size="32" font-weight="600" letter-spacing="0em"><tspan x="32" y="',
            namespaceYCoordinate.toString(),
            '">',
            _escape(namespace),
            "</tspan></text>"
        );
    }

    // Returns the SVG text for the username, and the lines of text used
    function _usernameText(uint256 tokenId) internal view virtual returns (string memory, uint256, uint256) {
        string memory username = _toLowercase(IERC721Namespace(msg.sender).getUsernameByTokenId(tokenId));
        uint256 usernameLength = bytes(username).length;
        uint256 fontSize;
        uint256 amountOfLines;
        uint256 yCoordinateStartOfText;
        string memory usernameTextSpans;
        if (usernameLength <= 17) {
            // Use single line
            if (usernameLength <= 11) {
                fontSize = 52;
            } else if (usernameLength == 12) {
                fontSize = 48;
            } else if (usernameLength == 13) {
                fontSize = 44;
            } else if (usernameLength == 14) {
                fontSize = 41;
            } else if (usernameLength == 15) {
                fontSize = 38;
            } else if (usernameLength == 16) {
                fontSize = 36;
            } else {
                // usernameLength == 17
                fontSize = 34;
            }
            usernameTextSpans = string.concat('<tspan x="32" y="468">', _escape(username), "</tspan>");
            yCoordinateStartOfText = 468;
            amountOfLines = 1;
        } else {
            uint256 charsToBorrow = 0;
            // More than 17 characters, use multiple lines
            fontSize = 33;
            uint256 charsPerLineWithMultilineFontSize = 17;
            // Break into multiple lines
            amountOfLines = usernameLength / charsPerLineWithMultilineFontSize;
            if (usernameLength % charsPerLineWithMultilineFontSize != 0) {
                amountOfLines++;
            }
            if (amountOfLines > 4) {
                // Fix to 4 lines and put '...' at the end
                amountOfLines = 4;
                username = string.concat(_slice(username, 0, 17 * 4 - 2), "...");
            } else {
                uint256 charsInLastLine = usernameLength % charsPerLineWithMultilineFontSize;
                if (charsInLastLine != 0 && charsInLastLine < 3) {
                    // Borrow chars from previous line to make last line have 3 chars
                    charsToBorrow = 3 - charsInLastLine;
                }
            }
            // Last line at 471, then each line above goes up -42 Y coordinates up
            yCoordinateStartOfText = 471 - 42 * (amountOfLines - 1);
            for (uint256 i = 0; i < amountOfLines - 1; i++) {
                uint256 sliceEnd = (i + 1) * charsPerLineWithMultilineFontSize;
                if (i == amountOfLines - 2) {
                    sliceEnd -= charsToBorrow;
                }
                usernameTextSpans = string.concat(
                    usernameTextSpans,
                    '<tspan x="32" y="',
                    _asString(471 - 42 * (amountOfLines - i - 1)),
                    '">',
                    _escape(_slice(username, i * charsPerLineWithMultilineFontSize, sliceEnd)),
                    "</tspan>"
                );
            }
            usernameTextSpans = string.concat(
                usernameTextSpans,
                '<tspan x="32" y="',
                _asString(471),
                '">',
                _escape(
                    _slice(
                        username,
                        (amountOfLines - 1) * charsPerLineWithMultilineFontSize - charsToBorrow,
                        bytes(username).length
                    )
                ),
                "</tspan>"
            );
        }
        string memory usernameTextSvg = string.concat(
            '<text xml:space="preserve" fill="#2C2D30" font-family="sans-serif" font-size="',
            fontSize.toString(),
            '" font-weight="600" letter-spacing="0em" style="fill:#2c2d30;fill:color(display-p3 .1725 .1765 .1882);fill-opacity:1">',
            usernameTextSpans,
            "</text>"
        );
        return (usernameTextSvg, yCoordinateStartOfText, amountOfLines);
    }

    function _slice(string memory str, uint256 start, uint256 end) internal pure virtual returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        assembly {
            mcopy(add(result, 0x20), add(strBytes, add(start, 0x20)), sub(end, start))
        }
        return string(result);
    }

    function _escape(string memory str) internal pure virtual returns (string memory) {
        uint256 i = 0;
        uint256 length = bytes(str).length;
        while (i < length) {
            bytes1 char = bytes(str)[i];
            if (char == "&") {
                // & -> &amp;
                str = string.concat(_slice(str, 0, i), "&amp;", _slice(str, i + 1, length));
                length += 4;
                i += 4;
            } else if (char == "<") {
                // < -> &lt;
                str = string.concat(_slice(str, 0, i), "&lt;", _slice(str, i + 1, length));
                length += 3;
                i += 3;
            } else if (char == ">") {
                // > -> &gt;
                str = string.concat(_slice(str, 0, i), "&gt;", _slice(str, i + 1, length));
                length += 3;
                i += 3;
            } else if (char == '"') {
                // " -> &quot;
                str = string.concat(_slice(str, 0, i), "&quot;", _slice(str, i + 1, length));
                length += 5;
                i += 5;
            } else if (char == "'") {
                // ' -> &#39;
                str = string.concat(_slice(str, 0, i), "&#39;", _slice(str, i + 1, length));
                length += 4;
                i += 4;
            } else {
                i++;
            }
        }
        return str;
    }

    function _asString(uint256 value) internal pure virtual returns (string memory) {
        return value.toString();
    }

    function _toLowercase(string memory str) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        for (uint256 i = 0; i < strBytes.length; i++) {
            bytes1 char = strBytes[i];
            // Check if character is uppercase (A-Z)
            if (char >= "A" && char <= "Z") {
                // Convert to lowercase by adding 32
                strBytes[i] = bytes1(uint8(char) + 32);
            }
        }
        return string(strBytes);
    }
}
