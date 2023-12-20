// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol, 18) {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
