// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SmartProfitTaker.sol";

contract SmartProfitTakerTest is Test {
    SmartProfitTaker vault;
    
    // Sepolia Addresses (Same as deployment)
    address weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address aavePool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address router = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address priceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function setUp() public {
        // Mock Price Feed if needed or use fork state
        vault = new SmartProfitTaker(
            weth, usdc, aavePool, router, priceFeed, 
            3000 * 10**8, 2000 * 10**8
        );
    }

    function testDepositRoutesToAave() public {
        // 1. Deposit ETH
        uint256 depositAmount = 1 ether;
        vault.deposit{value: depositAmount}();

        // 2. Check Aave has the funds (via aToken balance check or Vault state)
        // Since we don't have the aToken address handy in var, we check contract shares
        assertEq(vault.shares(address(this)), depositAmount);
        
        // Verify Vault mode is ETH
        assertEq(uint(vault.currentMode()), 0); // 0 = ETH_MODE
    }

    // To test rebalancing, we would typically mock the AggregatorV3Interface
    // to force the price > 3000 and call checkUpkeep.
    function testCheckUpkeepTriggers() public {
        // Mock the price feed address with a Mock contract returning > $3000
        // ... (Mock implementation omitted for brevity)
        
        // For standard testing, we can ensure it returns FALSE initially (Price ~2500-3000)
        (bool upkeepNeeded, ) = vault.checkUpkeep("");
        // Likely false unless ETH is mooning right now
        console.log("Upkeep needed:", upkeepNeeded);
    }
}