// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.17;

import {DSTest} from "lib/forge-std/lib/ds-test/src/test.sol";
import {console} from "../utils/Console.sol";
import {DiamondTest, Diamond} from "../utils/DiamondTest.sol";
import {Vm} from "forge-std/Vm.sol";
import {GenericSwapFacet} from "src/app/facets/GenericSwapFacet.sol";
import {LibSwap} from "src/libraries/LibSwap.sol";
import {LibAllowList} from "src/libraries/LibAllowList.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {UniswapV2Router02} from "../utils/Interfaces.sol";
import {ForkHelper} from "test/utils/ForkHelper.sol";

contract GenericSwapFacetTest is DSTest, DiamondTest {
    event GenericSwapCompleted(
        bytes32 indexed transactionId,
        string integrator,
        string referrer,
        address receiver,
        address fromAssetId,
        address toAssetId,
        uint256 fromAmount
    );

    // Events
    event Log(string message, bytes data);

    // uint256 toAmount

    // These values are for Mainnet
    address internal constant USDC_HOLDER = 0xee5B5B923fFcE93A870B3104b7CA09c3db80047A;
    address internal constant SOME_WALLET = 0x552008c0f6870c2f77e5cC1d2eb9bdff03e30Ea0;
    address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // Tokens
    address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // Tokens for testing
    address public IN_TOKEN = USDC_ADDRESS;
    address public OUT_TOKEN = DAI_ADDRESS;

    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Diamond internal diamond;
    GenericSwapFacet internal genericSwapFacet;
    ERC20 internal inToken;
    ERC20 internal outToken;
    UniswapV2Router02 internal uniswap;
    ForkHelper internal forkHelper;

    function setUp() public {
        forkHelper = new ForkHelper();
        forkHelper.fork(vm);

        diamond = createDiamond();

        genericSwapFacet = new GenericSwapFacet();
        inToken = ERC20(IN_TOKEN);
        outToken = ERC20(OUT_TOKEN);
        uniswap = UniswapV2Router02(UNISWAP_V2_ROUTER);

        bytes4[] memory functionSelectors = new bytes4[](3);
        functionSelectors[0] = genericSwapFacet.swapTokensGeneric.selector;
        functionSelectors[1] = genericSwapFacet.addDex.selector;
        functionSelectors[2] = genericSwapFacet.setFunctionApprovalBySignature.selector;

        addFacet(diamond, address(genericSwapFacet), functionSelectors);

        // Make call to addDex
        (bool success,) =
            address(diamond).call(abi.encodeWithSelector(genericSwapFacet.addDex.selector, address(uniswap)));
        assertTrue(success, "Add dex failed");

        // Make call to setFunctionApprovalBySignature
        (success,) = address(diamond).call(
            abi.encodeWithSelector(
                genericSwapFacet.setFunctionApprovalBySignature.selector, uniswap.swapExactTokensForTokens.selector
            )
        );
        assertTrue(success, "Set function approval by signature failed");
    }

    function test1CanSwapERC20() public {
        vm.startPrank(USDC_HOLDER);
        // usdc.approve(address(genericSwapFacet), 10_000 * 10 ** usdc.decimals());
        inToken.approve(address(diamond), 10_000 * 10 ** inToken.decimals());

        // Conosole log the names of the tokens
        console.log("IN_TOKEN: %s", inToken.name());
        console.log("OUT_TOKEN: %s", outToken.name());

        // Swap USDC to DAI
        address[] memory path = new address[](2);
        path[0] = IN_TOKEN;
        path[1] = OUT_TOKEN;

        uint256 initialAmountIn = 1_000 * 10 ** inToken.decimals();
        console.log("Amount to swap of InToken: %s", initialAmountIn);

        // uint256 amountOut = 10 * 10 ** (dai.decimals() - 5);
        uint256 amountOut = uniswap.getAmountsOut(initialAmountIn, path)[1];
        console.log("Amount to receive of OutToken: %s", amountOut);

        // Setting up swap data for swapping USDC to DAI from USDC_HOLDER
        uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        uint256 amountIn = amounts[0];
        console.log("amountIn: %s", amountIn);
        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            IN_TOKEN,
            OUT_TOKEN,
            amountIn,
            abi.encodeWithSelector(
                uniswap.swapExactTokensForTokens.selector,
                amountIn,
                amountOut,
                path,
                address(diamond),
                block.timestamp + 20 minutes
            ),
            true
        );

        // Check USDCHolder's USDC balance before swap
        uint256 holderInTokenBalance = inToken.balanceOf(USDC_HOLDER);
        console.log("USDC_HOLDER IN_TOKEN balance before swap: %s", holderInTokenBalance);

        // Check caller's DAI balance before swap
        uint256 holderOutTokenBalance = outToken.balanceOf(address(USDC_HOLDER));
        console.log("USDC_HOLDER OUT_TOKEN balance before swap: %s", holderOutTokenBalance);

        ////////////////////////////////////////////
        ////////////        SWAP          //////////
        ////////////////////////////////////////////

        // Make call to swapTokensGeneric //////////
        (bool success2,) = address(diamond).call(
            abi.encodeWithSelector(
                genericSwapFacet.swapTokensGeneric.selector, "", "", "", payable(USDC_HOLDER), amountOut, swapData
            )
        );
        assertTrue(success2);

        // Check caller's USDC balance after swap
        holderInTokenBalance = inToken.balanceOf(address(USDC_HOLDER));
        console.log("USDC_HOLDER INT_TOKEN balance after swap: %s", holderInTokenBalance);

        // Check caller's DAI balance after swap
        uint256 holderOutTokenBalanceAfterSwap = outToken.balanceOf(address(USDC_HOLDER));
        console.log("USDC_HOLDER OUT_TOKEN balance after swap: %s", holderOutTokenBalanceAfterSwap);

        // Define the percentage for calculating the difference. In this case, it's set to 1%.
        uint256 percentage = 1;

        // Calculate the difference based on the percentage of the amountOut.
        // This will be used to create a range (min and max) within which the holderOutTokenBalanceAfterSwap should fall.
        uint256 difference = amountOut * percentage / 100;

        // Calculate the minimum acceptable value for holderOutTokenBalanceAfterSwap.
        // It's the amountOut minus the calculated difference.
        uint256 min = amountOut - difference;

        // Calculate the maximum acceptable value for holderOutTokenBalanceAfterSwap.
        // It's the amountOut plus the calculated difference.
        uint256 max = amountOut + difference;

        // Assert that the holderOutTokenBalanceAfterSwap is within the acceptable range (between min and max).
        // If it's not, the transaction will fail and revert all changes.
        assertTrue(holderOutTokenBalanceAfterSwap >= min && holderOutTokenBalanceAfterSwap <= max);

        vm.stopPrank();
    }
}
