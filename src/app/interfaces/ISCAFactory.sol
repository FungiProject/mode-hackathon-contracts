// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISCAFactory {
    function createSmartContractAccount(address _diamondAddress, address _owner)
        external
        returns (address newAccountAddress);
    function getCreatedSmartContractAccounts() external view returns (address[] memory);
    function getSmartContractAccountsByOwner(address owner) external view returns (address[] memory);
    function getSmartContractAccountCount() external view returns (uint256);
}
