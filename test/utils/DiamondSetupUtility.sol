// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DSTest} from "lib/forge-std/lib/ds-test/src/test.sol";
import {console} from "./Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DiamondTest, Diamond} from "../utils/DiamondTest.sol";
import {GenericSwapFacet} from "src/app/facets/GenericSwapFacet.sol";
import {LibSwap} from "src/libraries/LibSwap.sol";
import {UniswapV2Router02} from "../utils/Interfaces.sol";
import {TokenFaucetHelper} from "test/utils/TokenFaucetHelper.sol";
import {ERC4626, Math, SafeERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ForkHelper} from "test/utils/ForkHelper.sol";
import {OwnershipFacet} from "src/core/facets/OwnershipFacet.sol";
import {SCAFactory} from "src/app/facets/SCAFactory.sol";

contract DiamondSetupUtility is DSTest, DiamondTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    // Contract instances
    Diamond internal diamond;
    GenericSwapFacet internal genericSwapFacet;
    TokenFaucetHelper internal tokenFaucetHelper;
    UniswapV2Router02 internal uniswap;
    ForkHelper internal forkHelper;
    OwnershipFacet internal ownershipFacet;

    // Addresses
    // address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNISWAP_V2_ROUTER = 0x5951479fE3235b689E392E9BC6E968CE10637A52;
    // 0x5951479fE3235b689E392E9BC6E968CE10637A52 // Mode V2Router

    // Selector setters
    bytes4[] swapperFunctionSelectors = new bytes4[](3);
    bytes4[] scaFactoryFunctionSelectors = new bytes4[](4);

    function setUpDiamond() internal returns (Diamond) {
        forkHelper = new ForkHelper();
        forkHelper.fork(vm);

        // Deploy the diamond with DiamondCutFacet, DiamondLoupeFacet, and OwnershipFacet
        diamond = createDiamond();

        // DEPLOY THE SWAPPER FACET

        // Set the instance of the dex to be uniswap with the router address
        uniswap = UniswapV2Router02(UNISWAP_V2_ROUTER);

        // Deploy the GenericSwapFacet
        genericSwapFacet = new GenericSwapFacet();

        // Set the swapper function selectors which will be stored in the diamond
        swapperFunctionSelectors[0] = genericSwapFacet.swapTokensGeneric.selector;
        swapperFunctionSelectors[1] = genericSwapFacet.addDex.selector;
        swapperFunctionSelectors[2] = genericSwapFacet.setFunctionApprovalBySignature.selector;

        // Add the GenericSwapFacet to the diamond
        addFacet(diamond, address(genericSwapFacet), swapperFunctionSelectors);

        // Perform the setup for the newly added GenericSwapFacet
        // This consists of setting the dex address and the function selectors
        (bool success,) =
            address(diamond).call(abi.encodeWithSelector(genericSwapFacet.addDex.selector, address(uniswap)));
        assertTrue(success, "Adding dex failed");

        // Make call to set function approval by signature
        (success,) = address(diamond).call(
            abi.encodeWithSelector(
                genericSwapFacet.setFunctionApprovalBySignature.selector, uniswap.swapExactTokensForTokens.selector
            )
        );
        assertTrue(success, "Setting function approval by signature failed");

        // DEPLOY_SCAFACTORY_FACET
        SCAFactory scaFactory = new SCAFactory();

        // Set the SCAFactory function selectors
        scaFactoryFunctionSelectors[0] = scaFactory.createSmartContractAccount.selector;
        scaFactoryFunctionSelectors[1] = scaFactory.getCreatedSmartContractAccounts.selector;
        scaFactoryFunctionSelectors[2] = scaFactory.getSmartContractAccountsByOwner.selector;
        scaFactoryFunctionSelectors[3] = scaFactory.getSmartContractAccountCount.selector;

        // Add the SCAFactory to the diamond
        addFacet(diamond, address(scaFactory), scaFactoryFunctionSelectors);

        return diamond;
    }
}
