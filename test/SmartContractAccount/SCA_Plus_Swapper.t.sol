// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DSTest} from "lib/forge-std/lib/ds-test/src/test.sol";
import {console} from "../utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SmartContractAccount} from "src/SmartContractAccount/SmartContractAccount.sol";
import {DiamondTest, Diamond} from "../utils/DiamondTest.sol";
import {GenericSwapFacet} from "src/app/facets/GenericSwapFacet.sol";
import {LibSwap} from "src/libraries/LibSwap.sol";
import {UniswapV2Router02} from "../utils/Interfaces.sol";
import {TokenFaucetHelper} from "test/utils/TokenFaucetHelper.sol";

import {ForkHelper} from "test/utils/ForkHelper.sol";

contract SmartContractAccount_Swap_Test is DSTest, DiamondTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    // Contracts
    Diamond internal diamond;
    SmartContractAccount internal smartContractAccount;
    GenericSwapFacet internal genericSwapFacet;
    UniswapV2Router02 internal uniswap;
    ERC20 internal inToken;
    ERC20 internal outToken;

    TokenFaucetHelper internal tokenFaucet;

    ForkHelper internal forkHelper;

    address internal constant USDC_HOLDER = 0xee5B5B923fFcE93A870B3104b7CA09c3db80047A;
    address internal constant SOME_WALLET = 0x552008c0f6870c2f77e5cC1d2eb9bdff03e30Ea0;
    address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // Tokens (Mainnet)
    address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WETH_PRICEFEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Mainnet values
    address constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant USDC_PRICEFEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    // TOKENS FOR TESTING
    address public IN_TOKEN = DAI_ADDRESS;
    address public OUT_TOKEN = WETH_ADDRESS;

    uint256 public startingBalance;

    bytes4[] swapperFunctionSelectors = new bytes4[](3);

    event DiamondInteraction(address indexed facet, uint256 selectorIndex, bytes data, uint256 timestamp);

    function setUp() public {
        forkHelper = new ForkHelper();
        forkHelper.fork(vm);

        inToken = ERC20(IN_TOKEN);
        outToken = ERC20(OUT_TOKEN);

        //////////////////////////////////////
        // Setting up Diamond ////////////////
        //////////////////////////////////////
        diamond = createDiamond();

        // Setting GenericSwap Facet and adding it to the diamond
        genericSwapFacet = new GenericSwapFacet();
        uniswap = UniswapV2Router02(UNISWAP_V2_ROUTER);

        swapperFunctionSelectors[0] = genericSwapFacet.swapTokensGeneric.selector;
        swapperFunctionSelectors[1] = genericSwapFacet.addDex.selector;
        swapperFunctionSelectors[2] = genericSwapFacet.setFunctionApprovalBySignature.selector;

        addFacet(diamond, address(genericSwapFacet), swapperFunctionSelectors);

        // Make call to add dex to the genericSwapFace
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

        //////////////////////////////////////
        // Setting up SmartContractAccount ///
        //////////////////////////////////////
        smartContractAccount = new SmartContractAccount(address(diamond), address(this));

        tokenFaucet = new TokenFaucetHelper(address(vm));

        // Use the helper to provide the manager address with USDC
        startingBalance = 500 * 10 ** ERC20(address(inToken)).decimals();
        tokenFaucet.provideERC20TokenTo(address(inToken), address(this), startingBalance);

        // Transfer the USDC to the SmartContractAccount
        inToken.transfer(address(smartContractAccount), startingBalance);
        // Check the balance of the SmartContractAccount
        assertEq(inToken.balanceOf(address(smartContractAccount)), startingBalance);
        console.log("SmartContractAccount balance: %s", inToken.balanceOf(address(smartContractAccount)));
    }

    function test1CanSwapTokens() public {
        assertEq(
            inToken.balanceOf(address(smartContractAccount)),
            startingBalance,
            "SmartContractAccount did not receive tokens"
        );

        console.log("IN_TOKEN: %s", inToken.name());
        console.log("OUT_TOKEN: %s", outToken.name());

        // Swap 100 denAsset for outToken
        address[] memory path = new address[](2);
        path[0] = IN_TOKEN;
        path[1] = OUT_TOKEN;

        console.log("Amount to swap of InToken: %s", inToken.balanceOf(address(smartContractAccount)));

        uint256 amountIn = 100 * 10 ** ERC20(address(IN_TOKEN)).decimals();
        uint256 amountOut = uniswap.getAmountsOut(amountIn, path)[1];
        console.log("Amount to receive of out token: %s", amountOut);

        // Setting up swap data for swapping denAsset (inToken) to ouToken
        // uint256[] memory amounts = uniswap.getAmountsIn(amountOut, path);
        // uint256 amountIn = amounts[0];
        console.log("Amount to send of in token: %s", amountIn);

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

        // Check the balance before the swap
        uint256 initialBalance = inToken.balanceOf(address(smartContractAccount));
        console.log("Initial balance of out token: %s", initialBalance);

        // Check the inToken balance before the swap
        uint256 initialBalanceOutToken = outToken.balanceOf(address(smartContractAccount));
        console.log("Initial balance of in token: %s", initialBalanceOutToken);

        // Swap the tokens

        bytes memory data_ = abi.encodeWithSelector(
            genericSwapFacet.swapTokensGeneric.selector,
            "",
            "",
            "",
            payable(address(smartContractAccount)),
            amountOut,
            swapData
        );

        // Approve the diamond to spend the inToken on behalf of the SmartContractAccount
        smartContractAccount.approveERC20(address(inToken), address(diamond), amountIn);

        // Call the GenericSwapFacet using the SmartContractAccount
        vm.expectEmit(true, true, true, true);
        emit DiamondInteraction(address(genericSwapFacet), 0, data_, block.timestamp);

        (bool success, bytes memory result) = smartContractAccount.callDiamond(address(genericSwapFacet), 0, data_);
        assertTrue(success, "Swap tokens failed");

        // Decode the result to get the tokens received
        address tokenOut = abi.decode(result, (address));
        console.log("Token out: %s", tokenOut);

        // Check the inToken balance after the swap
        uint256 finalBalance = inToken.balanceOf(address(smartContractAccount));
        console.log("Final balance of out token: %s", finalBalance);

        // Check the outToken balance after the swap
        uint256 finalBalanceOutToken = outToken.balanceOf(address(smartContractAccount));
        console.log("Final balance of in token: %s", finalBalanceOutToken);

        assertTrue(outToken.balanceOf(address(smartContractAccount)) > 0, "Fund balance has not decreased");
    }

    // function test1CanSwapTokens() public {
    //     // Arrange
    //     address[] memory path = new address[](2);
    //     path[0] = IN_TOKEN;
    //     path[1] = OUT_TOKEN;

    //     // Act
    //     bytes memory data_ = abi.encodeWithSelector(
    //         genericSwapFacet.swapTokensGeneric.selector,
    //         "",
    //         "",
    //         "",
    //         payable(address(smartContractAccount)),
    //         uniswap.getAmountsOut(100 * 10 ** ERC20(address(IN_TOKEN)).decimals(), path)[1],
    //         new LibSwap.SwapData[](1)
    //     );

    //     // Assert
    //     // vm.prank(address(this)); // Forge function to simulate call from non-owner
    //     (bool success,) = address(smartContractAccount).call(
    //         abi.encodeWithSelector(smartContractAccount.callDiamond.selector, address(genericSwapFacet), 0, data_)
    //     );

    //     assertTrue(success, "Non-owner should not be able to perform swaps");
    // }

    function test2SwapOnlyByOwner() public {
        // Arrange: Set up swap parameters
        address nonOwner = address(0x1234); // Use an arbitrary non-owner address
        uint256 amountToSwap = 100 * 10 ** ERC20(address(inToken)).decimals();
        address[] memory path = new address[](2);
        path[0] = IN_TOKEN;
        path[1] = OUT_TOKEN;

        // Encode swap data
        bytes memory data_ = abi.encodeWithSelector(
            genericSwapFacet.swapTokensGeneric.selector,
            "",
            "",
            "",
            payable(address(smartContractAccount)),
            uniswap.getAmountsOut(amountToSwap, path)[1],
            new LibSwap.SwapData[](1)
        );

        // Act & Assert: Attempt to swap as a non-owner and expect it to fail
        vm.prank(nonOwner); // Forge function to simulate call from non-owner
        (bool success,) = address(smartContractAccount).call(
            abi.encodeWithSelector(smartContractAccount.callDiamond.selector, address(genericSwapFacet), 0, data_)
        );

        assertTrue(!success, "Non-owner should not be able to perform swaps");
    }
}
