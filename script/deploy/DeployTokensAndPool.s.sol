// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "lib/forge-std/src/Console.sol";
import {IUniswapV2Router02} from "test/external/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "test/external/IUniswapV2Factory.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";

/// This script deploys the tokens and pools to test swapper in sepolia mode

contract DeployTokensAndPool is Script {
    //Sepolia mode address
    IUniswapV2Router02 internal uniswapRouter = IUniswapV2Router02(0x5951479fE3235b689E392E9BC6E968CE10637A52);
    IUniswapV2Factory internal uniswapFactory = IUniswapV2Factory(0x9fBFa493EC98694256D171171487B9D47D849Ba9);

    function run() external {
        uint256 deployerPK = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address deployerAddress = vm.envAddress("SEPOLIA_DIAMOND_OWNER");

        vm.startBroadcast(deployerPK);

        // Deploy and mint tokens
        (ERC20Mock USDC_MOCK, ERC20Mock USDT_MOCK) = deployAndMintTokens(deployerAddress);

        // Create liquidity pool
        createLiquidityPool(USDC_MOCK, USDT_MOCK, deployerAddress);

        // Mint tokens to deployer
        uint256 amountToAddA = 1000 * 10 ** USDC_MOCK.decimals();
        uint256 amountToAddB = 1000 * 10 ** USDT_MOCK.decimals();
        USDC_MOCK.mint(deployerAddress, amountToAddA);
        USDT_MOCK.mint(deployerAddress, amountToAddB);

        vm.stopBroadcast();
    }

    function deployAndMintTokens(address deployerAddress) internal returns (ERC20Mock, ERC20Mock) {
        ERC20Mock USDC_MOCK = new ERC20Mock("USDC", "USDC", 6);
        ERC20Mock USDT_MOCK = new ERC20Mock("USDT", "USDT", 6);
        console.log("USDC deployed: %s", address(USDC_MOCK));
        console.log("USDT deployed: %s", address(USDT_MOCK));

        uint256 amountToAddA = 1000 * 10 ** USDC_MOCK.decimals();
        uint256 amountToAddB = 1000 * 10 ** USDT_MOCK.decimals();
        USDC_MOCK.mint(deployerAddress, amountToAddA);
        USDT_MOCK.mint(deployerAddress, amountToAddB);

        return (USDC_MOCK, USDT_MOCK);
    }

    function createLiquidityPool(ERC20Mock USDC_MOCK, ERC20Mock USDT_MOCK, address deployerAddress) internal {
        uint256 amountToAddA = 1000 * 10 ** USDC_MOCK.decimals();
        uint256 amountToAddB = 1000 * 10 ** USDT_MOCK.decimals();

        USDC_MOCK.approve(address(uniswapRouter), amountToAddA);
        USDT_MOCK.approve(address(uniswapRouter), amountToAddB);

        uniswapRouter.addLiquidity(
            address(USDC_MOCK),
            address(USDT_MOCK),
            amountToAddA,
            amountToAddB,
            0,
            0,
            deployerAddress,
            block.timestamp + 100
        );

        address pool = uniswapFactory.getPair(address(USDC_MOCK), address(USDT_MOCK));
        console.log("Pool deployed: %s", pool);
    }
}
