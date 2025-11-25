// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BaseForkedTest } from "./BaseForkedTest.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console } from "forge-std/console.sol";

contract KipuBankV3Test is BaseForkedTest {

    function test_DepositErc20() public {

        // Array of 3 elements to store tokens
        uint256[3] memory amountIn = [
            uint256(USDC_INITIAL_AMOUNT),
            uint256(WETH_INITIAL_AMOUNT),
            uint256(LINK_INITIAL_AMOUNT)
        ];

        // Array of 3 elements to store address of tokens
        address[3] memory token = [
            address(USDC_ADDRESS),
            address(WETH_ADDRESS),
            address(LINK_ADDRESS)
        ];

        // Array of 3 elements to store the name of each token
        string[3] memory tokenName = [
            "USDC",
            "WETH",
            "LINK"
        ];

        for(uint256 i = 0; i < 3; i++)
        {
            console.log("Starting test of token %s", tokenName[i]);

            // Test with FAKE_ACCOUNT
            vm.startPrank(FAKE_ACCOUNT);

            // Previously: Approve swap to transfer WETH from FAKE_ACCOUNT
            IERC20(token[i]).approve(address(sKipu), amountIn[i]);

            //uint256 usdcBefore = usdc.balanceOf(FAKE_ACCOUNT);
            uint256 usdcBefore = sKipu.balanceOf(FAKE_ACCOUNT);

            // Call to make a ERC20 deposit.
            sKipu.DepositErc20(amountIn[i], token[i]);

            uint256 usdcAfter = sKipu.balanceOf(FAKE_ACCOUNT);

            vm.stopPrank();

            console.log("USDC in account before:", usdcBefore);
            console.log("USDC in account after:" , usdcAfter);
            assertGt(usdcAfter, usdcBefore, "USDC amount didn't change");

            console.log("Test finished\n");
        }
    }

    function test_DepositEth() public {

            console.log("Starting test of token ETH");

            // Test with FAKE_ACCOUNT
            vm.startPrank(FAKE_ACCOUNT);

            // Previously: Approve swap to transfer WETH from FAKE_ACCOUNT
            //IERC20(token[i]).approve(address(sKipu), amountIn[i]);

            //uint256 usdcBefore = usdc.balanceOf(FAKE_ACCOUNT);
            uint256 usdcBefore = sKipu.balanceOf(FAKE_ACCOUNT);

            // Call to make a ERC20 deposit.
            sKipu.DepositEth{value: 0.0001 ether}();

            uint256 usdcAfter = sKipu.balanceOf(FAKE_ACCOUNT);

            vm.stopPrank();

            console.log("USDC in account before:", usdcBefore);
            console.log("USDC in account after:" , usdcAfter);
            assertGt(usdcAfter, usdcBefore, "USDC amount didn't change");

            console.log("Test finished\n");
    }
}