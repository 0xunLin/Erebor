// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SmartProfitTaker.sol";

contract DeploySmartProfitTaker is Script {
    function run() external {
        // SEPOLIA ADDRESSES (Verify these before deployment)
        address weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        address usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC implementation or faucet
        address aavePool = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951; // Aave V3 Pool Sepolia
        address router = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E; // Uniswap V3 Router
        address priceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // ETH/USD Feed

        // Thresholds: Sell at $3000, Buy back at $2000
        uint256 highThreshold = 3000 * 10**8;
        uint256 lowThreshold = 2000 * 10**8;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        SmartProfitTaker vault = new SmartProfitTaker(
            weth,
            usdc,
            aavePool,
            router,
            priceFeed,
            highThreshold,
            lowThreshold
        );

        vm.stopBroadcast();
        
        console.log("Vault deployed at:", address(vault));
    }
}