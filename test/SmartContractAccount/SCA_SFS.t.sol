// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DSTest} from "lib/forge-std/lib/ds-test/src/test.sol";
import {console} from "../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {SmartContractAccount} from "src/SmartContractAccount/SmartContractAccount.sol";
import {TokenFaucetHelper} from "test/utils/TokenFaucetHelper.sol";
import {IRegister} from "../../src/external/IRegister.sol";

import {ForkHelper} from "test/utils/ForkHelper.sol";

contract SmartContractAccount_SFS is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    SmartContractAccount internal smartContractAccount;
    TokenFaucetHelper internal tokenFaucet;

    ForkHelper internal forkHelper;

    //Mode devNetwork
    address internal SFS_ADDRESS = 0xBBd707815a7F7eb6897C7686274AFabd7B579Ff6;
    IRegister internal SFS_CONTRACT = IRegister(SFS_ADDRESS);
    address internal SFS_OWNER = 0x266F06ede79EFE072cacf65657cFC3fED9Ef84Ad; //Owner of contract SFS
    address internal PROTOCOL_MANAGER = 0xee5B5B923fFcE93A870B3104b7CA09c3db80047A; //Random address

    uint256 internal tokenId;

    event EtherReceived(address sender, uint256 amount);

    function setUp() public {
        forkHelper = new ForkHelper();
        forkHelper.fork(vm);

        //Register this contract to get an initial NFT owned by PROTOCOL_MANAGER
        SFS_CONTRACT.register(PROTOCOL_MANAGER);
        tokenId = SFS_CONTRACT.getTokenId(address(this));

        smartContractAccount = new SmartContractAccount(address(this), address(this), SFS_ADDRESS, tokenId);
    }

    function test1_SmartAccountShouldRegisteredInSFSContract() public {
        bool isRegistered = SFS_CONTRACT.isRegistered(address(smartContractAccount));
        assertTrue(isRegistered, "Smart contract account is not registered."); 
    }

    function test2_ProtocolManagerShouldOwnNFT() public {
        address ownerTokenId = SFS_CONTRACT.ownerOf(tokenId);
        assertTrue(ownerTokenId == PROTOCOL_MANAGER, "Protocol Manager not own NFT of smart account registered");
    }

    function test3_DistributeFeesAndWithdraw() public {
        uint256 balanceTokenBeforeDistributing = SFS_CONTRACT.balances(tokenId);
        assertTrue(balanceTokenBeforeDistributing == 0, "Token balance should be zero if fees have not been distributed.");

        //Simulate tx
        uint256 amount = 1 ether;
        vm.deal(address(smartContractAccount), amount); // Send Ether to the contract
        vm.expectEmit(true, true, true, true);
        emit EtherReceived(address(this), amount);
        address(smartContractAccount).call{value: amount}(""); // Trigger receive function

        //At least one block needs to be skiped for the owner to distribute the fees
        uint256 feesToDistributing = 100000000;
        vm.roll(block.number+10);
        vm.startPrank(SFS_OWNER);
        SFS_CONTRACT.distributeFees{value: feesToDistributing}(tokenId, address(smartContractAccount), block.number);
        vm.stopPrank();

        uint256 balanceTokenAfterDistributing = SFS_CONTRACT.balances(tokenId);
        assertTrue(balanceTokenAfterDistributing == feesToDistributing, "The fees after distribution are not as expected.");
        
        //Withdraw fees generates with SmartAccount transactions
        uint256 balanceProtocolManagerBefore = address(PROTOCOL_MANAGER).balance;
        assertTrue(balanceProtocolManagerBefore == 0, "Protocol manager already had eth.");

        vm.startPrank(PROTOCOL_MANAGER);
        SFS_CONTRACT.withdraw(tokenId, address(PROTOCOL_MANAGER), balanceTokenAfterDistributing);
        vm.stopPrank();

        uint256 balanceProtocolManagerAfter = address(PROTOCOL_MANAGER).balance;
        assertTrue(balanceProtocolManagerAfter == feesToDistributing, "Protocol manager should have fees generated in the transaction.");
    }

}
