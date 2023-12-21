// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "lib/forge-std/src/Console.sol";
import {IUniswapV2Router02} from "test/external/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "test/external/IUniswapV2Factory.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {LibSwap} from "src/libraries/LibSwap.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";
import {GenericSwapFacet} from "src/app/facets/GenericSwapFacet.sol";

contract DeployTokensAndPool is Script {
    // Sepolia mode addresses
    IUniswapV2Router02 internal uniswapRouter = IUniswapV2Router02(0x5951479fE3235b689E392E9BC6E968CE10637A52);
    // IUniswapV2Factory internal uniswapFactory = IUniswapV2Factory(0x9fBFa493EC98694256D171171487B9D47D849Ba9);

    GenericSwapFacet internal genericSwapFacet;
    address public diamond = 0x7bd4BD975545D58b82FAdbd4798E8b1721dFbac8;

    // Token addresses
    address internal constant USDC_ADDRESS = 0xF058a84e41d773c7Df18DD5510FfFA97dfA9cD70;
    address internal constant USDT_ADDRESS = 0x3cCA2734824F04d653816b96e279824bE59D6625;

    function run() external {
        uint256 deployerPK = vm.envUint("SEPOLIA_PRIVATE_KEY");
        // address deployerAddress = vm.envAddress("SEPOLIA_DIAMOND_OWNER");
        address smartContractAccount = 0x6F5f630195DD5fd29E6e4d5B0f5D807619cd3600;

        vm.startBroadcast(deployerPK);

        // Reference to existing token contracts
        IERC20 USDC_MOCK = IERC20(USDC_ADDRESS);
        IERC20 USDT_MOCK = IERC20(USDT_ADDRESS);

        // Create liquidity pool
        // createLiquidityPool(USDC_MOCK, USDT_MOCK, deployerAddress);

        // Prepare swap data
        bytes memory data_ = prepareSwapData(USDC_MOCK, USDT_MOCK, smartContractAccount);
        console.log("Prepared Swap Data: ");
        console.logBytes(data_);

        vm.stopBroadcast();
    }

    function prepareSwapData(IERC20 IN_TOKEN, IERC20 OUT_TOKEN, address smartContractAccount)
        internal
        view
        returns (bytes memory data_)
    {
        // Setup the swap parameters
        address[] memory path = new address[](2);
        path[0] = address(IN_TOKEN);
        path[1] = address(OUT_TOKEN);

        uint256 amountIn = 10 * 10 ** 6;
        uint256 amountOut = uniswapRouter.getAmountsOut(amountIn, path)[1];

        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);
        swapData[0] = LibSwap.SwapData(
            address(uniswapRouter),
            address(uniswapRouter),
            address(IN_TOKEN),
            address(OUT_TOKEN),
            amountIn,
            abi.encodeWithSelector(
                uniswapRouter.swapExactTokensForTokens.selector,
                amountIn,
                amountOut,
                path,
                address(diamond), // Assuming 'diamond' is defined and set correctly
                block.timestamp + 20 minutes
            ),
            true
        );

        // Encode the swap data
        data_ = abi.encodeWithSelector(
            genericSwapFacet.swapTokensGeneric.selector, "", "", "", payable(smartContractAccount), amountOut, swapData
        );

        return data_;
    }
}
