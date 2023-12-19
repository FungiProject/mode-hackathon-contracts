// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "src/mirror/SCAMirror.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IRegister} from "src/external/IRegister.sol";

contract SmartContractAccount is SCAMirror {
    // Modifier for reentrancy guard
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // Address of the owner (could be the diamond or another entity)
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Events for logging transfers and interactions
    event EtherReceived(address sender, uint256 amount);
    event TokenReceived(address operator, address from, uint256 tokenId, bytes data);
    event ERC20Transferred(address indexed token, address indexed to, uint256 amount);
    event ERC721Transferred(address indexed token, address indexed to, uint256 tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DiamondInteraction(address indexed facet, uint256 selectorIndex, bytes data, uint256 timestamp);

    constructor(address _diamondAddress, address _owner, address _sfsContract, uint256 _tokenId) {
        require(_diamondAddress != address(0), "Diamond address cannot be the zero address.");
        setDiamond(_diamondAddress);
        owner = _owner;
        IRegister(_sfsContract).assign(_tokenId);
    }

    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
        // Log Ether transfer data here
    }

    // Function to set the diamond address
    function setInteractionDiamond(address _diamond) external onlyOwner {
        require(_diamond != address(0), "Diamond address cannot be the zero address.");
        setDiamond(_diamond);
    }

    // Utilize inherited functions for interacting with the diamond's facets
    function callDiamond(address _facetAddress, uint256 _selectorIndex, bytes memory _data)
        public
        payable
        onlyOwner
        nonReentrant
        returns (bool success, bytes memory result)
    {
        (success, result) = callFacet(_data);
        if (success) {
            emit DiamondInteraction(_facetAddress, _selectorIndex, _data, block.timestamp);
        }
    }

    // Function for static calls to a facet
    function staticCallDiamond(bytes memory _data) public view returns (bool success, bytes memory result) {
        (success, result) = staticCallFacet(_data);
        require(success, "Facet call failed");
    }

    // Function to transfer ownership of the contract
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address.");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Function to transfer ERC20 tokens
    function transferERC20(address token, address to, uint256 amount) public onlyOwner nonReentrant {
        require(token != address(0), "Token address cannot be the zero address.");
        require(to != address(0), "Recipient address cannot be the zero address.");
        require(amount > 0, "Amount must be greater than 0.");

        IERC20(token).transfer(to, amount);
        emit ERC20Transferred(token, to, amount);
    }

    // Function to transfer ERC721 tokens
    function transferERC721(address token, address to, uint256 tokenId) public onlyOwner nonReentrant {
        require(token != address(0), "Token address cannot be the zero address.");
        require(to != address(0), "Recipient address cannot be the zero address.");
        // require(tokenId > 0, "Token ID must be greater than 0.");

        IERC721(token).transferFrom(address(this), to, tokenId);
        emit ERC721Transferred(token, to, tokenId);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
        public
        virtual
        returns (bytes4)
    {
        // Handle the receipt of an ERC721 token
        emit TokenReceived(operator, from, tokenId, data);

        return this.onERC721Received.selector;
    }

    // Function to transfer ETH
    function transferEther(address payable to, uint256 amount) public onlyOwner nonReentrant {
        require(to != address(0), "Recipient address cannot be the zero address.");
        require(amount > 0, "Amount must be greater than 0.");

        to.transfer(amount);
        emit EtherReceived(to, amount);
    }

    // Approve ERC20 token transfers
    function approveERC20(address token, address spender, uint256 amount) public onlyOwner nonReentrant {
        require(token != address(0), "Token address cannot be the zero address.");
        require(spender != address(0), "Spender address cannot be the zero address.");
        require(amount > 0, "Amount must be greater than 0.");

        IERC20(token).approve(spender, amount);
    }

    // Function to retrieve the balance of the contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Function to retrieve the balance of an ERC20 token
    function getTokenBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // Function to retrieve the balance of an ERC721 token
    function getERC721TokenOwner(address token, uint256 tokenId) public view returns (address) {
        return IERC721(token).ownerOf(tokenId);
    }
}
