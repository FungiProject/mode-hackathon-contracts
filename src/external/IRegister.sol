
pragma solidity ^0.8.23;

interface IRegister {
    function register(address _recipient) external returns (uint256 tokenId);
    function assign(uint256 _tokenId) external returns (uint256);
    function isRegistered(address _contract) external returns (bool isREgistered);
    function getTokenId(address _contract) external returns (uint256 tokenId);
    function balances(uint256 _tokenId) external returns(uint256 balances);
    function withdraw(uint256 _tokenId, address _recipient, uint256 _blockNumber) external;
    function distributeFees(uint256 _tokenId, address _smartContract, uint256 _blockNumber) external payable;
    function getBalanceUpdatedBlock(address _contract) external returns (uint256);
    function ownerOf(uint256 _tokenId) external returns (address);
}