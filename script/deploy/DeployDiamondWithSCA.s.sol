// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {IDiamondCut} from "src/core/interfaces/IDiamondCut.sol";
import {Diamond} from "src/core/Diamond.sol";
import {DiamondCutFacet} from "src/core/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "src/core/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "src/core/facets/OwnershipFacet.sol";
import {GenericSwapFacet} from "src/app/facets/GenericSwapFacet.sol";
import {SCAFactory} from "src/app/facets/SCAFactory.sol";
import {console} from "lib/forge-std/src/Console.sol";

/// This script deploys the diamond contract and all the basic Fungi Protocol facets, it then cuts the facets to the diamond

struct DeployedContracts {
    address diamondCutFacetAddress;
    address diamondAddress;
    address diamondLoupeFacetAddress;
    address diamondOwnershipFacetAddress;
    address genericSwapFacetAddress;
    address scaFactoryFacetAddress;
}

contract DeployDiamond is Script {
    IDiamondCut.FacetCut[] internal cut;

    error NotDeployed(string contractName);

    function run() external returns (DeployedContracts memory deployedContracts, bytes memory data) {
        // uint256 deployerPK = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY"); // Deploy on localhost
        uint256 deployerPK = vm.envUint("SEPOLIA_PRIVATE_KEY"); // Deploy on Sepolia

        address diamondOwner = vm.envAddress("SEPOLIA_DIAMOND_OWNER"); // Address that will pay for the deployment gas fees
        // address diamondOwner = vm.envAddress("LOCAL_DIAMOND_OWNER"); // Address that will pay for the deployment gas fees

        vm.startBroadcast(deployerPK);
        // Deploy facets
        DiamondCutFacet diamondCut = new DiamondCutFacet();
        console.log("diamondCutFacetAddress: %s", address(diamondCut));

        DiamondLoupeFacet diamondLoupe = new DiamondLoupeFacet();
        console.log("diamondLoupeFacetAddress: %s", address(diamondLoupe));

        OwnershipFacet ownership = new OwnershipFacet();
        console.log("diamondOwnershipFacetAddress: %s", address(ownership));

        GenericSwapFacet genericSwap = new GenericSwapFacet();
        console.log("genericSwapFacetAddress: %s", address(genericSwap));

        SCAFactory scaFactory = new SCAFactory();
        console.log("scaFactoryFacetAddress: %s", address(scaFactory));

        Diamond diamond = new Diamond(
            diamondOwner,
            address(diamondCut)
        );
        console.log("diamondAddress: %s", address(diamond));

        bytes4[] memory functionSelectors;

        // Diamond Loupe

        functionSelectors = new bytes4[](5);
        functionSelectors[0] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        functionSelectors[1] = DiamondLoupeFacet.facets.selector;
        functionSelectors[2] = DiamondLoupeFacet.facetAddress.selector;
        functionSelectors[3] = DiamondLoupeFacet.facetAddresses.selector;
        functionSelectors[4] = DiamondLoupeFacet.supportsInterface.selector;

        // console log function selectors
        console.log("Diamond Loupe Facet Function Selectors");
        for (uint256 i = 0; i < functionSelectors.length; i++) {
            console.logBytes4(functionSelectors[i]);
        }

        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(diamondLoupe),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        // Ownership Facet

        functionSelectors = new bytes4[](4);
        functionSelectors[0] = OwnershipFacet.transferOwnership.selector;
        functionSelectors[1] = OwnershipFacet.cancelOwnershipTransfer.selector;
        functionSelectors[2] = OwnershipFacet.confirmOwnershipTransfer.selector;
        functionSelectors[3] = OwnershipFacet.owner.selector;

        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(ownership),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        // GenericSwap Facet

        functionSelectors = new bytes4[](3);
        functionSelectors[0] = genericSwap.swapTokensGeneric.selector;
        functionSelectors[1] = genericSwap.addDex.selector;
        functionSelectors[2] = genericSwap.setFunctionApprovalBySignature.selector;

        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(genericSwap),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        // SCAFactory Facet

        functionSelectors = new bytes4[](3);
        functionSelectors[0] = scaFactory.createSmartContractAccount.selector;
        functionSelectors[1] = scaFactory.getCreatedSmartContractAccounts.selector;
        functionSelectors[2] = scaFactory.getSmartContractAccountCount.selector;

        cut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(scaFactory),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: functionSelectors
            })
        );

        // Encode the data for diamondCut
        data = abi.encodeWithSelector(
            IDiamondCut.diamondCut.selector,
            cut,
            address(0), // Replace with target address if needed
            "" // Additional data if needed
        );

        // DiamondCutFacet(address(diamond)).diamondCut(cut, address(0), "");

        // Store addresses in struct
        deployedContracts = DeployedContracts({
            diamondCutFacetAddress: address(diamondCut),
            diamondLoupeFacetAddress: address(diamondLoupe),
            diamondOwnershipFacetAddress: address(ownership),
            diamondAddress: address(diamond),
            genericSwapFacetAddress: address(genericSwap),
            scaFactoryFacetAddress: address(scaFactory)
        });

        // Perform Cut to the diamond
        bytes memory output = abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cut, address(0), "");

        // Make a call to the diamond with the output data and perform the cut
        (bool success, bytes memory returnData) = address(diamond).call(output);
        if (!success) {
            revert(string(returnData));
        }

        vm.stopBroadcast();

        delete cut;

        return (deployedContracts, data);
    }
}
