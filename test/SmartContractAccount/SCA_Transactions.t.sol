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

import {ForkHelper} from "test/utils/ForkHelper.sol";

contract SmartContractAccount_Transactions is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    SmartContractAccount internal smartContractAccount;
    TokenFaucetHelper internal tokenFaucet;
    ERC20 internal inToken;

    ForkHelper internal forkHelper;

    //Mode devNetwork
    address internal SFS_ADDRESS = 0xBBd707815a7F7eb6897C7686274AFabd7B579Ff6;
    uint256 internal tokenId = 1;

    address internal constant USDC_HOLDER = 0xee5B5B923fFcE93A870B3104b7CA09c3db80047A;
    address internal constant SOME_WALLET = 0x552008c0f6870c2f77e5cC1d2eb9bdff03e30Ea0;

    // Tokens (Mainnet)
    address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public IN_TOKEN = USDC_ADDRESS;

    uint256 public startingBalance;

    event TokenReceived(address operator, address from, uint256 tokenId, bytes data);
    event EtherReceived(address sender, uint256 amount);
    event ERC20Transferred(address indexed token, address indexed to, uint256 amount);
    event ERC721Transferred(address indexed token, address indexed to, uint256 tokenId);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        forkHelper = new ForkHelper();
        forkHelper.fork(vm);

        inToken = ERC20(IN_TOKEN);

        //////////////////////////////////////
        // Setting up SmartContractAccount ///
        //////////////////////////////////////
        smartContractAccount = new SmartContractAccount(address(this), address(this),SFS_ADDRESS, tokenId);

        // Deploy the TokenFaucetHelper contract
        tokenFaucet = new TokenFaucetHelper(address(vm));

        // Use the helper to provide the manager address with USDC
        startingBalance = 500 * 10 ** ERC20(address(inToken)).decimals();
        tokenFaucet.provideERC20TokenTo(address(inToken), address(this), startingBalance); // Providing 2 denAsset
    }

    function test1_canReceiveUSDC() public {
        // Transfer the USDC to the SmartContractAccount
        inToken.transfer(address(smartContractAccount), startingBalance / 2);
        // Check the balance of the SmartContractAccount
        assertEq(inToken.balanceOf(address(smartContractAccount)), startingBalance / 2);
        console.log("SmartContractAccount balance: %s", inToken.balanceOf(address(smartContractAccount)));
    }

    function test2CanTransferUSDC() public {
        test1_canReceiveUSDC();

        // Capture the inToken balance of SOME_WALLET
        uint256 balanceBefore = inToken.balanceOf(SOME_WALLET);
        console.log("SOME_WALLET balance before: %s", balanceBefore);

        // Transfer the USDC to SOME_WALLET
        smartContractAccount.transferERC20(address(inToken), SOME_WALLET, startingBalance / 4);

        // Check the balance of SOME_WALLET
        uint256 balanceAfter = inToken.balanceOf(SOME_WALLET);
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
        smartContractAccount.transferERC721(address(testMinter), SOME_WALLET, tokenId);

        // Verify the token is now owned by the specified address
        assertEq(testMinter.ownerOf(tokenId), SOME_WALLET, "Token transfer from SmartContractAccount failed");
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

    ///////////////////////////////////////
    /// Helper Functions /////////////////
    ///////////////////////////////////////

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
