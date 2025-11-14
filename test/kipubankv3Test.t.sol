// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BaseForkedTest } from "./BaseForkedTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console } from "forge-std/console.sol";

contract KipuBankV3Test is BaseForkedTest {

    // TESTS:
    //  - ERC20 -> USDC
    function test_DepositErc20() public {

        uint256 amountIn = USDC_INITIAL_AMOUNT;
        //uint256 amountIn = WETH_INITIAL_AMOUNT;
        //uint256 amountIn = LINK_INITIAL_AMOUNT;

        console.log("Starting test");

        // Test with FAKE_ACCOUNT
        vm.startPrank(FAKE_ACCOUNT);

        // Previously: Approve swap to transfer WETH from FAKE_ACCOUNT
        IERC20(USDC_ADDRESS).approve(address(sKipu), amountIn);
        //IERC20(WETH_ADDRESS).approve(address(sKipu), amountIn);
        //IERC20(LINK_ADDRESS).approve(address(sKipu), amountIn);

        //uint256 usdcBefore = usdc.balanceOf(FAKE_ACCOUNT);
        uint256 usdcBefore = sKipu.balanceOf(FAKE_ACCOUNT);

        // Call to make a ERC20 deposit.
        sKipu.DepositErc20(amountIn, USDC_ADDRESS);
        //sKipu.DepositErc20(amountIn, WETH_ADDRESS);
        //sKipu.DepositErc20(amountIn, LINK_ADDRESS);

        //uint256 usdcAfter = usdc.balanceOf(FAKE_ACCOUNT);
        uint256 usdcAfter = sKipu.balanceOf(FAKE_ACCOUNT);

        vm.stopPrank();

        console.log("USDC in account before:", usdcBefore);
        console.log("USDC in account after:" , usdcAfter);
        assertGt(usdcAfter, usdcBefore, "usdc amount didn't change");

        console.log("Test finished");
    }
}