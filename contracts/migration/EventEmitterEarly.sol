// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./EventEmitter.sol";

contract EventEmitterEarly is EventEmitter {
    function _allowedToEmitEvents() internal view override returns (bool) {
        return block.number < 30_000;
    }
}
