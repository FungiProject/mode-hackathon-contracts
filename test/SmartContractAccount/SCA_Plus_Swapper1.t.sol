// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {DSTest} from "lib/forge-std/lib/ds-test/src/test.sol";
import {console} from "../utils/Console.sol";
import {ERC20Mock} from "../utils/ERC20Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {SmartContractAccount} from "src/SmartContractAccount/SmartContractAccount.sol";
import {DiamondTest, Diamond} from "../utils/DiamondTest.sol";
import {GenericSwapFacet} from "src/app/facets/GenericSwapFacet.sol";
import {LibSwap} from "src/libraries/LibSwap.sol";
import {IUniswapV2Router02} from "../external/IUniswapV2Router02.sol";

import {ForkHelper} from "test/utils/ForkHelper.sol";

contract SmartContractAccount_Swap_Test1 is DSTest, DiamondTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    // Contracts
    Diamond internal diamond;
    SmartContractAccount internal smartContractAccount;
    GenericSwapFacet internal genericSwapFacet;
    IUniswapV2Router02 internal uniswap;

    ForkHelper internal forkHelper;

    address internal constant UNISWAP_V2_ROUTER = 0x5951479fE3235b689E392E9BC6E968CE10637A52; //Mode
    address internal SFS_ADDRESS = 0xBBd707815a7F7eb6897C7686274AFabd7B579Ff6;

    //Mock tokens
    ERC20Mock internal USDC_MOCK_CONTRACT;
    ERC20Mock internal USDT_MOCK_CONTRACT;

    ERC20Mock internal IN_TOKEN;
    ERC20Mock internal OUT_TOKEN;
    
    uint256 public startingBalance;

    bytes4[] swapperFunctionSelectors = new bytes4[](3);

    event DiamondInteraction(address indexed facet, uint256 selectorIndex, bytes data, uint256 timestamp);

    function setUp() public {
        forkHelper = new ForkHelper();
        forkHelper.fork(vm);
        USDC_MOCK_CONTRACT = new ERC20Mock("USDC", "USDC", 6);
        USDT_MOCK_CONTRACT = new ERC20Mock("USDT", "USDT", 6);

        IN_TOKEN = USDC_MOCK_CONTRACT;
        OUT_TOKEN = USDT_MOCK_CONTRACT;

        setUpCreatePairAndAddLiquidity(address(USDC_MOCK_CONTRACT), address(USDT_MOCK_CONTRACT));

        diamond = createDiamond();

        // Setting GenericSwap Facet and adding it to the diamond
        genericSwapFacet = new GenericSwapFacet();
        uniswap = IUniswapV2Router02(UNISWAP_V2_ROUTER);

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

        smartContractAccount = new SmartContractAccount(address(diamond), address(this), SFS_ADDRESS, 0);

        startingBalance = 500 * 10 ** USDC_MOCK_CONTRACT.decimals();

        USDC_MOCK_CONTRACT.mint(address(smartContractAccount), startingBalance);
        assertEq(USDC_MOCK_CONTRACT.balanceOf(address(smartContractAccount)), startingBalance);

    }

    function setUpCreatePairAndAddLiquidity(address _tokenA, address _tokenB) public {
        uint256 amountToAddPoolA = 1000 * 10 ** ERC20Mock(_tokenA).decimals();
        uint256 amountToAddPoolB = 1000 * 10 ** ERC20Mock(_tokenB).decimals();
        ERC20Mock(_tokenA).mint(address(this), amountToAddPoolA);
        ERC20Mock(_tokenB).mint(address(this), amountToAddPoolB);

        ERC20Mock(_tokenA).approve(UNISWAP_V2_ROUTER, amountToAddPoolA);
        ERC20Mock(_tokenB).approve(UNISWAP_V2_ROUTER, amountToAddPoolB);
        IUniswapV2Router02(UNISWAP_V2_ROUTER).addLiquidity(_tokenA,_tokenB,amountToAddPoolA,amountToAddPoolB,0,0,address(this),block.timestamp);
    }


    function test1CanSwapTokens() public {
      
        // Swap 100 denAsset for outToken
        address[] memory path = new address[](2);
        path[0] = address(IN_TOKEN);
        path[1] = address(OUT_TOKEN);

        uint256 amountIn = 100 * 10 ** IN_TOKEN.decimals();
        uint256 amountOut = uniswap.getAmountsOut(amountIn, path)[1];
        console.log("Amount to receive of out token: %s", amountOut);
        console.log("Amount to send of in token: %s", amountIn);

        LibSwap.SwapData[] memory swapData = new LibSwap.SwapData[](1);

        swapData[0] = LibSwap.SwapData(
            address(uniswap),
            address(uniswap),
            address(IN_TOKEN),
            address(OUT_TOKEN),
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
        uint256 initialBalance = IN_TOKEN.balanceOf(address(smartContractAccount));
        console.log("Initial balance of in token: %s", initialBalance);

        // Check the inToken balance before the swap
        uint256 initialBalanceOutToken = OUT_TOKEN.balanceOf(address(smartContractAccount));
        console.log("Initial balance of out token: %s", initialBalanceOutToken);

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
        smartContractAccount.approveERC20(address(IN_TOKEN), address(diamond), amountIn);

        // Call the GenericSwapFacet using the SmartContractAccount
        vm.expectEmit(true, true, true, true);
        emit DiamondInteraction(address(genericSwapFacet), 0, data_, block.timestamp);

        (bool success, bytes memory result) = smartContractAccount.callDiamond(address(genericSwapFacet), 0, data_);
        assertTrue(success, "Swap tokens failed");

        // Check the inToken balance after the swap
        uint256 finalBalanceInToken = IN_TOKEN.balanceOf(address(smartContractAccount));
        console.log("Final balance of in token: %s", finalBalanceInToken);

        // Check the outToken balance after the swap
        uint256 finalBalanceOutToken = OUT_TOKEN.balanceOf(address(smartContractAccount));
        console.log("Final balance of out token: %s", finalBalanceOutToken);

        assertTrue(finalBalanceInToken == startingBalance-amountIn, "Fund balance of tokenIn has not decreased");
        assertTrue(finalBalanceOutToken > 0, "Fund balance of token out has not increased");
    }
}
