// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCurrency is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external payable virtual {
        _mint(to, amount);
    }

    function mint(uint256 amount) external payable virtual {
        _mint(msg.sender, amount);
    }

    function burn(address from, uint256 amount) external virtual {
        _burn(from, amount);
    }

    function burn(uint256 amount) external virtual {
        _burn(msg.sender, amount);
    }
}
