// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DSTest} from "lib/forge-std/lib/ds-test/src/test.sol";
import {console} from "../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SmartContractAccount} from "src/SmartContractAccount/SmartContractAccount.sol";
import {TokenFaucetHelper} from "test/utils/TokenFaucetHelper.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {TestMinter} from "test/utils/TestMinter.sol";
import {TestERC20} from "test/utils/TestERC20.sol";

import {ForkHelper} from "test/utils/ForkHelper.sol";

contract SmartContractAccount_Transactions is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    SmartContractAccount internal smartContractAccount;
    TokenFaucetHelper internal tokenFaucet;
    ERC20 internal inToken;

    ForkHelper internal forkHelper;

    //Mode devNetwork
    address internal SFS_ADDRESS = 0xBBd707815a7F7eb6897C7686274AFabd7B579Ff6;
    uint256 internal sfsTokenId = 1;

    address internal constant SOME_WALLET = 0x552008c0f6870c2f77e5cC1d2eb9bdff03e30Ea0;

    TestERC20 internal testERC20Token1;
    TestERC20 internal testERC20Token2;

    uint256 public startingBalance;

    event TokenReceived(address operator, address from, uint256 tokenId, bytes data);
    event EtherReceived(address sender, uint256 amount);
    event ERC20Transferred(address indexed token, address indexed to, uint256 amount);
    event ERC721Transferred(address indexed token, address indexed to, uint256 tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        forkHelper = new ForkHelper();
        forkHelper.fork(vm);

        testERC20Token1 = new TestERC20("TestToken1", "TT1");

        // Mint tokens to the test contract or other addresses as needed
        uint256 mintAmount = 1000 * 10 ** 18;
        testERC20Token1.mint(address(this), mintAmount);

        testERC20Token2 = new TestERC20("TestToken2", "TT2");

        // Mint tokens to the test contract or other addresses as needed
        mintAmount = 1000 * 10 ** 18;
        testERC20Token2.mint(address(this), mintAmount);

        inToken = testERC20Token1;

        startingBalance = mintAmount / 2;

        //////////////////////////////////////
        // Setting up SmartContractAccount ///
        //////////////////////////////////////
        smartContractAccount = new SmartContractAccount(address(this), address(this),SFS_ADDRESS, sfsTokenId);
    }

    function test1_canReceiveERC20() public {
        // Transfer the USDC to the SmartContractAccount
        inToken.transfer(address(smartContractAccount), startingBalance / 2);
        // Check the balance of the SmartContractAccount
        assertEq(inToken.balanceOf(address(smartContractAccount)), startingBalance / 2);
        console.log("SmartContractAccount balance: %s", inToken.balanceOf(address(smartContractAccount)));
    }

    function test2CanTransferUSDC() public {
        test1_canReceiveERC20();

        // Capture the inToken balance of THIS contract
        uint256 balanceBefore = inToken.balanceOf(address(this));
        console.log("THIS contract balance before: %s", balanceBefore);

        // Transfer the USDC to THIS contract
        smartContractAccount.transferERC20(address(inToken), address(this), startingBalance / 4);

        // Check the balance of THIS contract
        uint256 balanceAfter = inToken.balanceOf(address(this));
        console.log("SOME_WALLET balance after: %s", balanceAfter);
        assertEq(balanceAfter, balanceBefore + startingBalance / 4);
    }

    function test3CanReceiveERC721Tokens() public {
        TestMinter testMinter = new TestMinter();

        // Mint an ERC721 token
        uint256 mintQuantity = 1;
        uint256 paymentAmount = mintQuantity * testMinter.mintPrice();
        testMinter.mintToken{value: paymentAmount}(mintQuantity);

        uint256 tokenId = testMinter.totalMints() - 1;

        // Approve and transfer the ERC721 token to the SmartContractAccount
        approveTokenTransfer(IERC721(address(testMinter)), address(smartContractAccount), tokenId);
        testMinter.transferFrom(address(this), address(smartContractAccount), tokenId);

        // Verify the token is now owned by SmartContractAccount
        assertEq(
            testMinter.ownerOf(tokenId), address(smartContractAccount), "SmartContractAccount did not receive the token"
        );
    }

    function test4CanTransferERC721Tokens() public {
        TestMinter testMinter = new TestMinter();

        // Mint an ERC721 token directly to the SmartContractAccount
        uint256 mintQuantity = 1;
        uint256 paymentAmount = mintQuantity * testMinter.mintPrice();
        testMinter.mintToken{value: paymentAmount}(mintQuantity);
        uint256 tokenId = testMinter.totalMints() - 1;

        // Transfer the token to SmartContractAccount for setup
        approveTokenTransfer(IERC721(address(testMinter)), address(smartContractAccount), tokenId);
        testMinter.transferFrom(address(this), address(smartContractAccount), tokenId);

        // Transfer the token from SmartContractAccount to a specified address (e.g., SOME_WALLET)
        smartContractAccount.transferERC721(address(testMinter), address(this), tokenId);

        // Verify the token is now owned by the specified address
        assertEq(testMinter.ownerOf(tokenId), address(this), "Token transfer from SmartContractAccount failed");
    }

    function test5_EtherReceivedEvent() public {
        // Arrange
        uint256 amount = 1 ether;

        // Act
        vm.deal(address(smartContractAccount), amount); // Send Ether to the contract

        // Assert
        vm.expectEmit(true, true, true, true);
        emit EtherReceived(address(this), amount);
        address(smartContractAccount).call{value: amount}(""); // Trigger receive function
    }

    function test6_ERC20TransferredEvent() public {
        // Arrange
        uint256 amount = 100 * 10 ** ERC20(address(inToken)).decimals();
        inToken.transfer(address(smartContractAccount), amount);

        // Act
        vm.expectEmit(true, true, true, true);
        emit ERC20Transferred(address(inToken), SOME_WALLET, amount);
        smartContractAccount.transferERC20(address(inToken), SOME_WALLET, amount);

        // Assert
        assertEq(inToken.balanceOf(SOME_WALLET), amount, "ERC20 Transfer failed");
    }

    function test7_ERC721TransferredEvent() public {
        // Arrange
        TestMinter testMinter = new TestMinter();
        uint256 tokenId = 0; // Assuming this is the tokenId
        testMinter.mintToken{value: testMinter.mintPrice()}(1);
        testMinter.transferFrom(address(this), address(smartContractAccount), tokenId);

        // Act
        vm.expectEmit(true, true, true, true);
        emit ERC721Transferred(address(testMinter), SOME_WALLET, tokenId);
        smartContractAccount.transferERC721(address(testMinter), SOME_WALLET, tokenId);

        // Assert
        assertEq(testMinter.ownerOf(tokenId), SOME_WALLET, "ERC721 Transfer failed");
    }

    function test8_OwnershipTransferredEvent() public {
        // Arrange
        address newOwner = SOME_WALLET;

        // Act
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(this), newOwner);
        smartContractAccount.transferOwnership(newOwner);

        // Assert
        assertEq(smartContractAccount.owner(), newOwner, "Ownership transfer failed");
    }

    // ///////////////////////////////////////
    // /// Helper Functions /////////////////
    // ///////////////////////////////////////

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
        public
        virtual
        returns (bytes4)
    {
        // Handle the receipt of an ERC721 token
        emit TokenReceived(operator, from, tokenId, data);

        return this.onERC721Received.selector;
    }

    // Helper function to approve the SmartContractAccount to transfer an ERC721 token
    function approveTokenTransfer(IERC721 tokenContract, address approvedAccount, uint256 tokenId) internal {
        tokenContract.approve(approvedAccount, tokenId);
    }
}
