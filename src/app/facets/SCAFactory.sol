// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibSCAFactory} from "src/libraries/LibSCAFactory.sol";
import {SmartContractAccount} from "src/SmartContractAccount/SmartContractAccount.sol";

contract SCAFactory {
    // Events and other contract elements

    address internal immutable sfsRegister; 
    uint256 internal immutable tokenId;
    
    constructor(address _sfsRegister, uint256 _tokenId){
        sfsRegister = _sfsRegister;
        tokenId = _tokenId;
    }

    function createSmartContractAccount(address _diamondAddress, address _owner)
        public
        returns (address newAccountAddress)
    {
        require(_diamondAddress != address(0), "Diamond address cannot be the zero address.");

        SmartContractAccount newAccount = new SmartContractAccount(_diamondAddress, _owner, sfsRegister, tokenId);
        // Update the call to LibSCAFactory.addSmartContractAccount to include the owner
        LibSCAFactory.addSmartContractAccount(address(newAccount), _owner);

        return address(newAccount);
    }

    // Function to retrieve all SCAs created by this factory
    function getCreatedSmartContractAccounts() external view returns (address[] memory) {
        return LibSCAFactory.getSmartContractAccounts();
    }

    // Function to retrieve the SCAs created by a specific owner
    function getSmartContractAccountsByOwner(address owner) external view returns (address[] memory) {
        return LibSCAFactory.getSmartContractAccountsByOwner(owner);
    }

    // Function to retrieve the count of SCAs created
    function getSmartContractAccountCount() external view returns (uint256) {
        return LibSCAFactory.getSmartContractAccountCount();
    }
}
