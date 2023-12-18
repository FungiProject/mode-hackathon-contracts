// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DSTest} from "ds-test/test.sol";
import {DiamondSetupUtility} from "test/utils/DiamondSetupUtility.sol";
import {SCAFactory} from "src/app/facets/SCAFactory.sol";
import {SmartContractAccount} from "src/SmartContractAccount/SmartContractAccount.sol";
import {LibSCAFactory} from "src/libraries/LibSCAFactory.sol";
import {console} from "../utils/Console.sol";
import {DiamondTest, Diamond} from "../utils/DiamondTest.sol";

contract SCACreationTest is DSTest, DiamondSetupUtility {
    SCAFactory public scaFactory;

    function setUp() public {
        diamond = setUpDiamond(); // Assuming setUpDiamond returns a Diamond with SCAFactory facet
        scaFactory = SCAFactory(address(diamond));
    }

    function test1CreateSCAAndVerifyRegistration() public {
        // Simulate creating a SmartContractAccount calling createSCA()
        createSCA();

        // Verify that the SmartContractAccount is registered
        (bool success2, bytes memory result2) =
            address(diamond).call(abi.encodeWithSelector(scaFactory.getCreatedSmartContractAccounts.selector));
        require(success2, "Failed to get created SmartContractAccounts");

        // Decode the result
        address[] memory createdSCAs = abi.decode(result2, (address[]));
        console.log("Created SmartContractAccounts: ", createdSCAs[0]);
        assertEq(createdSCAs.length, 1, "There should be one SmartContractAccount");
    }

    function test2RetrieveCreatedSCAs() public {
        // Create multiple SCAs
        address sca1 = createSCA();
        address sca2 = createSCA();

        // Retrieve and verify
        address[] memory scas = scaFactory.getCreatedSmartContractAccounts();
        console.log("Number of SmartContractAccounts created: ", scas.length);
        for (uint256 i = 0; i < scas.length; i++) {
            console.log("SCA Address [", i, "]: ", scas[i]);
        }

        assertEq(scas.length, 2, "There should be two SmartContractAccounts");
        assertEq(scas[0], sca1, "First SCA address mismatch");
        assertEq(scas[1], sca2, "Second SCA address mismatch");
    }

    // Test calling the created SmartContractAccount
    function test3CallSCA() public {
        // Create an SCA
        address sca = createSCA();

        // Call the SCA
        (bool success, bytes memory result) = sca.call(abi.encodeWithSelector(bytes4(keccak256("getDiamond()"))));
        require(success, "Failed to call SCA");

        // Decode the result
        address diamondAddress = abi.decode(result, (address));
        console.log("Diamond address retrieved from SCA: ", diamondAddress);

        // Verify the diamond address
        assertEq(diamondAddress, address(diamond), "Diamond address mismatch");
    }

    function test4VerifyOwnerSCARegistration() public {
        // The owner who will create the SCA
        address owner = address(this);

        // Create a new SmartContractAccount
        address newSCA = createSCA();

        // Verify that the new SmartContractAccount is registered under the owner
        (bool success, bytes memory result) =
            address(diamond).call(abi.encodeWithSelector(scaFactory.getSmartContractAccountsByOwner.selector, owner));
        require(success, "Failed to get SCAs by owner");

        // Decode the result
        address[] memory scasByOwner = abi.decode(result, (address[]));

        assertEq(scasByOwner.length, 1, "Owner should have one registered SCA");
        assertEq(scasByOwner[0], newSCA, "Registered SCA address does not match the created one");

        // Log the result
        console.log("Owner's registered SCA address: ", scasByOwner[0]);
    }

    // Helper function to create a SmartContractAccount
    function createSCA() internal returns (address) {
        // Simulate creating a SmartContractAccount
        (bool success, bytes memory result) = address(diamond).call(
            abi.encodeWithSelector(scaFactory.createSmartContractAccount.selector, address(diamond), address(this))
        );
        require(success, "Failed to create SmartContractAccount");

        // Decode the result
        address newSCA = abi.decode(result, (address));
        console.log("New SmartContractAccount created at: ", newSCA);

        // Verify the creation event
        emit log_named_address("New SmartContractAccount created at: ", newSCA);

        return newSCA;
    }
}
