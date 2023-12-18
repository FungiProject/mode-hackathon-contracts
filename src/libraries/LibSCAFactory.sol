// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";

library LibSCAFactory {
    // Adds a new SmartContractAccount to the storage
    function addSmartContractAccount(address accountAddress, address owner) internal {
        AppStorage storage s = appStorage();
        s.smartContractAccounts.push(accountAddress);
        s.ownerToSCAs[owner].push(accountAddress); // Update mapping for the owner
        s.smartContractAccountCount++;
    }

    // Returns the list of all created SmartContractAccounts by a specific owner
    function getSmartContractAccountsByOwner(address owner) internal view returns (address[] memory) {
        AppStorage storage s = appStorage();
        return s.ownerToSCAs[owner];
    }

    // Returns the list of all created SmartContractAccounts
    function getSmartContractAccounts() internal view returns (address[] memory) {
        AppStorage storage s = appStorage();
        return s.smartContractAccounts;
    }

    // Increment the smartContractAccountCount
    function incrementSmartContractAccountCount() internal {
        AppStorage storage s = appStorage();
        s.smartContractAccountCount++;
    }

    // Get the current smartContractAccountCount
    function getSmartContractAccountCount() internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return s.smartContractAccountCount;
    }

    // Add any additional functions or functionalities as needed

    // Internal function to access the AppStorage
    function appStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0x0
        }
    }
}
