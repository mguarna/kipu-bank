// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {KipuBankV3} from "../src/kipubankv3.sol";

contract CKipuBankV3Script is Script {
    KipuBankV3 public kipubank;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        uint256 withdrawMaxAllowed = 60000000;  // 60 USDC
        uint256 bankCap = 300000000;            // 300 USDC

        // Metamask Wallet
        address owner = 0x1D32FEDB0ed19584921221F3fAF148bD4128Ea70;

        // Uniswap V2 Router (Sepolia)
        address uniswapV2Router = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

        // USDC Address (Sepolia)
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

        kipubank = new KipuBankV3(withdrawMaxAllowed, bankCap, owner, uniswapV2Router, usdc);

        vm.stopBroadcast();
    }
}
