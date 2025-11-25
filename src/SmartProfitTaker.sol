// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "lib/openzeppelin-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// Interfaces for Aave and Uniswap
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

contract SmartProfitTaker is Ownable, ReentrancyGuard, AutomationCompatibleInterface {
    using SafeERC20 for IERC20;

    // State Variables
    enum VaultMode { ETH_MODE, USDC_MODE }
    VaultMode public currentMode; // 

    // Configuration
    uint256 public highThreshold; // Price to sell ETH 
    uint256 public lowThreshold;  // Price to buy ETH 
    
    // Assets (Stagenet Addresses for Hackathons)
    address public immutable weth;
    address public immutable usdc;
    
    // External Contracts
    IPool public immutable aavePool;
    ISwapRouter public immutable uniswapRouter;
    AggregatorV3Interface public immutable priceFeed;

    // User Shares (Simplified accounting [cite: 16])
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    // Events
    event Deposit(address indexed user, uint256 amount, VaultMode mode);
    event Withdrawal(address indexed user, uint256 amount, address asset);
    event RebalanceExecuted(VaultMode newMode, uint256 price, uint256 amountSwapped);

    constructor(
        address _weth,
        address _usdc,
        address _aavePool,
        address _router,
        address _priceFeed,
        uint256 _highThreshold, // e.g., 3000 * 10**8 (Chainlink uses 8 decimals)
        uint256 _lowThreshold   // e.g., 1500 * 10**8
    ) Ownable(msg.sender) {
        weth = _weth;
        usdc = _usdc;
        aavePool = IPool(_aavePool);
        uniswapRouter = ISwapRouter(_router);
        priceFeed = AggregatorV3Interface(_priceFeed);
        highThreshold = _highThreshold;
        lowThreshold = _lowThreshold;
        currentMode = VaultMode.ETH_MODE; // Start in ETH mode usually
    }

    // --- User Interactions ---

    /**
     * @notice Deposits ETH, converts if needed, and supplies to Aave [cite: 12]
     */
    function deposit() external payable nonReentrant {
        require(msg.value > 0, "Zero deposit");

        uint256 sharesToMint = msg.value; // 1:1 share mapping for simplicity in ETH terms
        
        if (currentMode == VaultMode.ETH_MODE) {
            // [cite: 13] Wrap ETH to WETH and supply to Aave
            IWETH(weth).deposit{value: msg.value}();
            IERC20(weth).approve(address(aavePool), msg.value);
            aavePool.supply(weth, msg.value, address(this), 0);
        } else {
            // [cite: 14] Swap ETH -> USDC -> Supply Aave
            // 1. Wrap
            IWETH(weth).deposit{value: msg.value}();
            // 2. Swap WETH -> USDC
            uint256 usdcAmount = _swap(weth, usdc, msg.value);
            // 3. Supply USDC
            IERC20(usdc).approve(address(aavePool), usdcAmount);
            aavePool.supply(usdc, usdcAmount, address(this), 0);
        }

        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        emit Deposit(msg.sender, msg.value, currentMode);
    }

    /**
     * @notice Withdraws funds from Aave and returns current asset to user [cite: 15]
     */
    function withdraw(uint256 shareAmount) external nonReentrant {
        require(shares[msg.sender] >= shareAmount, "Insufficient shares");

        // Calculate proportion of total holdings
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        if (currentMode == VaultMode.ETH_MODE) {
            // Withdraw WETH from Aave
            // Note: In a real production vault, we would calculate exact asset share. 
            // For hackathon, we withdraw everything and send proportional amount to save gas/complexity.
            uint256 amountWithdrawn = aavePool.withdraw(weth, type(uint256).max, address(this));
            uint256 userAmount = (amountWithdrawn * shareAmount) / (totalShares + shareAmount);
            
            // Redeposit remaining
            uint256 remaining = amountWithdrawn - userAmount;
            if(remaining > 0) {
                IERC20(weth).approve(address(aavePool), remaining);
                aavePool.supply(weth, remaining, address(this), 0);
            }

            // Unwrap and send ETH
            IWETH(weth).withdraw(userAmount);
            payable(msg.sender).transfer(userAmount);
            emit Withdrawal(msg.sender, userAmount, weth);

        } else {
            // Withdraw USDC from Aave
            uint256 amountWithdrawn = aavePool.withdraw(usdc, type(uint256).max, address(this));
            uint256 userAmount = (amountWithdrawn * shareAmount) / (totalShares + shareAmount);
             
            // Redeposit remaining
            uint256 remaining = amountWithdrawn - userAmount;
             if(remaining > 0) {
                IERC20(usdc).approve(address(aavePool), remaining);
                aavePool.supply(usdc, remaining, address(this), 0);
            }
            
            IERC20(usdc).safeTransfer(msg.sender, userAmount);
            emit Withdrawal(msg.sender, userAmount, usdc);
        }
    }

    // --- Chainlink Automation ---

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price); // Assumes 8 decimals
    }

    /**
     * @notice Checks if rebalance is needed based on price thresholds [cite: 17]
     */
    function checkUpkeep(bytes calldata /* checkData */) 
        external 
        view 
        override 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        uint256 price = getLatestPrice();

        if (currentMode == VaultMode.ETH_MODE && price > highThreshold) {
            // Condition A: Take Profits 
            return (true, abi.encode(VaultMode.USDC_MODE));
        } 
        else if (currentMode == VaultMode.USDC_MODE && price < lowThreshold) {
            // Condition B: Buy Dip 
            return (true, abi.encode(VaultMode.ETH_MODE));
        }
        
        return (false, "");
    }

    /**
     * @notice Performs the rebalance (Atomic: Withdraw -> Swap -> Supply) [cite: 11, 23]
     */
    function performUpkeep(bytes calldata performData) external override nonReentrant {
        (bool upkeepNeeded, ) = this.checkUpkeep("");
        require(upkeepNeeded, "Upkeep not needed");

        VaultMode targetMode = abi.decode(performData, (VaultMode));
        uint256 currentPrice = getLatestPrice();

        if (targetMode == VaultMode.USDC_MODE) {
            // REBALANCE: ETH -> USDC [cite: 21]
            
            // 1. Withdraw ALL WETH from Aave
            uint256 wethBal = aavePool.withdraw(weth, type(uint256).max, address(this));
            
            // 2. Swap WETH -> USDC
            uint256 usdcReceived = _swap(weth, usdc, wethBal);
            
            // 3. Supply USDC to Aave
            IERC20(usdc).approve(address(aavePool), usdcReceived);
            aavePool.supply(usdc, usdcReceived, address(this), 0);
            
            currentMode = VaultMode.USDC_MODE;

        } else {
            // REBALANCE: USDC -> ETH [cite: 22]
            
            // 1. Withdraw ALL USDC from Aave
            uint256 usdcBal = aavePool.withdraw(usdc, type(uint256).max, address(this));
            
            // 2. Swap USDC -> WETH
            uint256 wethReceived = _swap(usdc, weth, usdcBal);
            
            // 3. Supply WETH to Aave
            IERC20(weth).approve(address(aavePool), wethReceived);
            aavePool.supply(weth, wethReceived, address(this), 0);
            
            currentMode = VaultMode.ETH_MODE;
        }

        emit RebalanceExecuted(currentMode, currentPrice, 0);
    }

    // --- Internal Helpers ---

    function _swap(address tokenIn, address tokenOut, uint256 amountIn) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(address(uniswapRouter), amountIn);

        // Security: In production, use oracle price to set amountOutMinimum
        // For hackathon, we use 0 or a slippage factor if oracle logic is added
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000, // 0.3% pool tier
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0, 
                sqrtPriceLimitX96: 0
            });

        amountOut = uniswapRouter.exactInputSingle(params);
    }

    // Allow contract to receive ETH when unwrapping
    receive() external payable {}
}