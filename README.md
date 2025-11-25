# 📈 Smart Profit Taker Vault

**Automated ETH Accumulation & Volatility Protection**

> 🏆 Built for the Contract.dev Early Builder Hackathon (November-December 2025)

## 📖 Overview

**Smart Profit Taker** is a DeFi vault that automates the "Buy Low, Sell High" strategy while generating passive yield.

Instead of keeping funds idle, the vault keeps assets fully deployed in **Aave V3** to earn lending interest[cite: 3, 8]. [cite_start]It utilizes **Chainlink Automation** and **Chainlink Price Feeds** to monitor the market 24/7[cite: 4, 5]. When ETH hits a "Take Profit" price, the vault automatically swaps to USDC. When ETH hits a "Buy Dip" price, it swaps back to ETH[cite: 6, 7].

## 🧩 Architecture

The system relies on a central interaction between three protocols[cite: 9]:

1.  **Aave V3/V2:** Used for holding funds (ETH or USDC) to generate continuous yield[cite: 2].
2.  **Uniswap V3:** Used for atomic swapping of assets during rebalancing[cite: 6].
3.  **Chainlink:**
    * **Price Feeds:** Provides accurate, tamper-proof ETH/USD data[cite: 5].
    * **Automation:** Triggers the `performUpkeep` function to execute swaps without manual intervention[cite: 4].

### Rebalancing Logic
* **ETH Mode:** Funds are in Aave as WETH.
    * *Trigger:* Price > High Threshold.
    * *Action:* Withdraw WETH → Swap to USDC → Supply USDC to Aave[cite: 6].
* **USDC Mode:** Funds are in Aave as USDC.
    * *Trigger:* Price < Low Threshold.
    * *Action:* Withdraw USDC → Swap to WETH → Supply WETH to Aave[cite: 6].

## 🛠️ Tech Stack

* **Smart Contracts:** Solidity (v0.8.20)
* **Framework:** Foundry (Forge, Cast)
* **Integrations:**
    * Chainlink Automation & Data Feeds
    * Uniswap V3 SwapRouter
    * Aave V3 Pool
* **Frontend:** Next.js, Wagmi, RainbowKit

## 🚀 Getting Started

### Prerequisites
* [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.
* A wallet with **Sepolia ETH** and **Sepolia LINK**.

### Installation

1. **Clone the repo:**
   ```bash
   git clone [https://github.com/yourusername/smart-profit-taker.git](https://github.com/yourusername/smart-profit-taker.git)
   cd smart-profit-taker