// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DSTest} from "lib/forge-std/lib/ds-test/src/test.sol";
import {console} from "../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenFaucetHelper {
    Vm private immutable vm;

    constructor(address _vmAddress) {
        vm = Vm(_vmAddress);
    }

    function provideERC20TokenTo(address _tokenAddress, address _to, uint256 _amount) external {
        IERC20 token = IERC20(_tokenAddress);

        // The address to impersonate should ideally be one with a large amount of the token
        // Find such an address from the respective token's rich list on a block explorer
        address richTokenHolder = 0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8; // Usually address at index 1 has tokens in testnets

        // Start by impersonating the rich token holder
        vm.startPrank(richTokenHolder);

        // Approve the transfer and send the token to the specified address
        token.transfer(_to, _amount);

        // Stop impersonating the rich token holder
        vm.stopPrank();
    }
}
