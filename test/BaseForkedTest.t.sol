// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";
import { KipuBankV3 } from "src/kipubankv3.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseForkedTest is Test {
    KipuBankV3 public sKipu;

    // Uniswap V2 Router (Mainnet)
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // USDC address on mainnet
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // WETH address on Mainnet
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // LINK Address on Mainnet
    address constant LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;

    // Contract owner
    address constant CONTRACT_OWNER = 0x1D32FEDB0ed19584921221F3fAF148bD4128Ea70;

    // Default bank cap in USD. ie 300 USD
    uint256 constant DEFAULT_BANK_CAPACTITY = 300e6;

    // Max USD permitted to withdraw per account. ie 60USD
    uint256 constant WITHDRAW_MAX = 60000000;

    IERC20 public usdc = IERC20(USDC_ADDRESS);
    IERC20 public weth = IERC20(WETH_ADDRESS);
    IERC20 public link = IERC20(LINK_ADDRESS);

    // Test account
    address constant FAKE_ACCOUNT = address(0x77);

    // WETH has 18 decimals. 1e14 = 0.0001 WETH.
    uint256 constant WETH_INITIAL_AMOUNT = 1e14;

    // USDC has 6 decimals. 100e6 = 100 USDC.
    uint256 constant USDC_INITIAL_AMOUNT = 100e6;

    // LINK has 18 decimals. 1e18 = 1 LINK.
    uint256 constant LINK_INITIAL_AMOUNT = 1e18;

    function setUp() public virtual {

        // create fork using env var ETH_RPC_URL
        string memory rpc = vm.envString("ETH_RPC_URL");
        vm.createSelectFork(rpc);

        // deploy contract
        sKipu = new KipuBankV3(WITHDRAW_MAX
            , DEFAULT_BANK_CAPACTITY
            , CONTRACT_OWNER
            , UNISWAP_V2_ROUTER
            , USDC_ADDRESS);

        // Fond account with ERC20 tokens
        deal(USDC_ADDRESS, FAKE_ACCOUNT, USDC_INITIAL_AMOUNT);
        deal(LINK_ADDRESS, FAKE_ACCOUNT, LINK_INITIAL_AMOUNT);
        deal(WETH_ADDRESS, FAKE_ACCOUNT, WETH_INITIAL_AMOUNT);

        // Fond account with native Ether
        //vm.deal(FAKE_ACCOUNT, WETH_INITIAL_AMOUNT);

        console.log("Fork created with RPC:", rpc);
        console.log("KipuBankV3 deployed:", address(sKipu));

        // Balancs
        console.log("WETH balance:", weth.balanceOf(FAKE_ACCOUNT));
        console.log("USDC balance:", usdc.balanceOf(FAKE_ACCOUNT));
        console.log("LINK balance:", link.balanceOf(FAKE_ACCOUNT));
        console.log('\n');
    }
}

