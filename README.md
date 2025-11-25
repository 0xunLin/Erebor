# 🏔️ Erebor: The Smart Profit Taker Vault

**Automated ETH Accumulation & Volatility Protection**

> 🏆 Built for the Contract.dev Early Builder Hackathon (November-December 2025)

![License](https://img.shields.io/badge/License-MIT-green.svg)
![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)

## 📖 Overview

**Erebor** is a DeFi vault designed to protect and grow your treasury automatically. Like the vast wealth of the Lonely Mountain, this vault manages your assets with precision.

Instead of keeping funds idle, Erebor keeps assets fully deployed in **Aave V3** to earn lending interest. It utilizes **Chainlink Automation** and **Chainlink Price Feeds** to execute a "Buy Low, Sell High" strategy 24/7 without manual intervention.

* **Take Profit:** When ETH rises, it swaps to USDC to lock in gains.
* **Buy the Dip:** When ETH falls, it swaps back to ETH to accumulate more tokens.

## 🧩 Architecture

The system relies on a central interaction between three protocols:

1.  **Aave V3:** Used for holding funds (ETH or USDC) to generate continuous yield.
2.  **Uniswap V3/V2:** Used for atomic swapping of assets during rebalancing.
3.  **Chainlink:**
    * **Price Feeds:** Provides accurate, tamper-proof ETH/USD data.
    * **Automation:** Triggers the `performUpkeep` function to execute swaps automatically.

### Rebalancing Logic
* **ETH Mode (Accumulation):** Funds are in Aave as WETH.
    * *Trigger:* Price > High Threshold.
    * *Action:* Withdraw WETH → Swap to USDC → Supply USDC to Aave.
* **USDC Mode (Safety):** Funds are in Aave as USDC.
    * *Trigger:* Price < Low Threshold.
    * *Action:* Withdraw USDC → Swap to WETH → Supply WETH to Aave.

## 🛠️ Tech Stack

* **Smart Contracts:** Solidity (v0.8.20)
* **Framework:** Foundry (Forge, Cast)
* **Integrations:**
    * Chainlink Automation & Data Feeds
    * Uniswap V3 SwapRouter
    * Aave V3/V2 Pool
* **Frontend:** Next.js, Wagmi, RainbowKit

## 🚀 Getting Started

### Prerequisites
* [Foundry](https://book.getfoundry.sh/getting-started/installation) installed.
* [contract.dev](https://app.contract.dev/).

### Installation

1.  **Clone the repo:**
    ```bash
    git clone [https://github.com/0xunLin/Erebor.git](https://github.com/0xunLin/Erebor.git)
    cd Erebor
    ```

2.  **Install dependencies:**
    ```bash
    forge install
    npm install
    ```

3.  **Set up environment:**
    Create a `.env` file in the root directory:
    ```bash
    PRIVATE_KEY=your_private_key
    STAGENET_RPC_URL=your_stagenet_rpc_url
    ```

### 🧪 Testing

We use Stagenets on [contract.dev](https://app.contract.dev) to test interactions with simulated Aave and Uniswap contracts.