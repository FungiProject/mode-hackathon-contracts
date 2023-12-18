// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import {Vm} from "forge-std/Vm.sol";

contract ForkHelper {
    function fork(Vm vm) public {
        string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
        // string memory rpcUrl = vm.envString("ARBITRUM_RPC_URL");
        // string memory rpcUrl = vm.envString("LATESTNET_NODE_URI");
        uint256 blockNumber = 18765997;
        vm.createSelectFork(rpcUrl, blockNumber);
    }

    function customFork(Vm vm, string memory rpcUrl, uint256 blockNumber) public {
        vm.createSelectFork(rpcUrl, blockNumber);
    }
}
