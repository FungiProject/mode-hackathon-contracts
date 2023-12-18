// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct AppStorage {
    address genericSwapFacet;
    address uniswapRouter; // Address of the Uniswap V2 router
    address[] smartContractAccounts;
    uint256 smartContractAccountCount;
    mapping(address => address[]) ownerToSCAs;
}
// Mapping of fund address to fund name

library LibAppStorage {
    function appStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0x0
        }
    }
}

contract Modifiers {
    AppStorage internal s;
}
