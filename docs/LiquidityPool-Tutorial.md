# Liquidity Pool Tutorial

This tutorial explains how to interact with the LiquidityPool contract, which implements an Automated Market Maker (AMM) for ETH/BACKR token trading on the Backr platform.

## Core Concepts

### Pool Mechanics
- Constant product AMM (x * y = k)
- 0.3% trading fee
- Minimum liquidity requirement
- Slippage protection
- Liquidity provider incentives

### Key Parameters
- `FEE_DENOMINATOR`: 1000 (0.3% fee)
- `FEE_NUMERATOR`: 3
- `MINIMUM_LIQUIDITY`: Set at deployment
- `maxSlippage`: Configurable maximum slippage (in basis points)

## Providing Liquidity

### Adding Initial Liquidity

```solidity
// First approve tokens
token.approve(liquidityPool, tokenAmount);

// Add liquidity
liquidityPool.addLiquidity{value: ethAmount}(tokenAmount);
```

**Important Notes**:
- First liquidity provider sets the initial price
- Must provide balanced amounts
- Minimum liquidity requirement must be met

### Adding Subsequent Liquidity

```solidity
// Calculate optimal token amount based on current ratio
uint256 ethReserve = liquidityPool.ethReserve();
uint256 tokenReserve = liquidityPool.tokenReserve();
uint256 optimalTokenAmount = (ethAmount * tokenReserve) / ethReserve;

// Approve and add liquidity
token.approve(liquidityPool, optimalTokenAmount);
liquidityPool.addLiquidity{value: ethAmount}(optimalTokenAmount);
```

### Removing Liquidity

```solidity
// Remove liquidity and receive both tokens and ETH
liquidityPool.removeLiquidity(liquidityAmount);
```

## Trading

### Swapping ETH for Tokens

```solidity
// Calculate minimum tokens to receive
uint256 minTokens = calculateMinTokens(ethAmount);

// Perform swap
liquidityPool.swapETHForTokens{value: ethAmount}(minTokens);
```

### Swapping Tokens for ETH

```solidity
// Calculate minimum ETH to receive
uint256 minETH = calculateMinETH(tokenAmount);

// Approve tokens and swap
token.approve(liquidityPool, tokenAmount);
liquidityPool.swapTokensForETH(tokenAmount, minETH);
```

### Calculating Output Amounts

```solidity
// Get expected output amount
uint256 outputAmount = liquidityPool.getOutputAmount(
    inputAmount,
    inputReserve,
    outputReserve
);
```

## Price Calculations

### Getting Exchange Rate

```solidity
// Get current exchange rate (tokens per ETH)
uint256 rate = liquidityPool.getExchangeRate();
```

### Calculating Price Impact

```javascript
// Example price impact calculation
function calculatePriceImpact(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) {
    const k = inputReserve * outputReserve;
    const newInputReserve = inputReserve + inputAmount;
    const newOutputReserve = k / newInputReserve;
    const outputAmount = outputReserve - newOutputReserve;
    
    const spotPrice = outputReserve / inputReserve;
    const executionPrice = outputAmount / inputAmount;
    const priceImpact = (spotPrice - executionPrice) / spotPrice * 100;
    
    return priceImpact;
}
```

## Events to Monitor

1. Liquidity Events:
   ```solidity
   event LiquidityAdded(
       address indexed provider,
       uint256 ethAmount,
       uint256 tokenAmount,
       uint256 liquidity
   );
   event LiquidityRemoved(
       address indexed provider,
       uint256 ethAmount,
       uint256 tokenAmount,
       uint256 liquidity
   );
   ```

2. Trading Events:
   ```solidity
   event TokensPurchased(
       address indexed buyer,
       uint256 ethIn,
       uint256 tokensOut
   );
   event TokensSold(
       address indexed seller,
       uint256 tokensIn,
       uint256 ethOut
   );
   ```

3. Pool State Events:
   ```solidity
   event PoolStateChanged(
       uint256 newEthReserve,
       uint256 newTokenReserve
   );
   event MaxSlippageUpdated(uint256 newMaxSlippage);
   ```

## Best Practices

1. **Adding Liquidity**
   - Calculate optimal amounts
   - Consider price impact
   - Monitor pool share
   - Check minimum liquidity

2. **Trading**
   - Set reasonable slippage limits
   - Calculate price impact
   - Monitor gas prices
   - Check output amounts

3. **Removing Liquidity**
   - Consider timing
   - Monitor pool share
   - Check expected returns
   - Account for fees

4. **Price Monitoring**
   - Track exchange rate
   - Monitor reserves
   - Watch for arbitrage
   - Consider external prices

## Complete Examples

### Liquidity Provider Flow

```solidity
// 1. Calculate optimal token amount
uint256 ethAmount = 1 ether;
uint256 ethReserve = liquidityPool.ethReserve();
uint256 tokenReserve = liquidityPool.tokenReserve();
uint256 tokenAmount = (ethAmount * tokenReserve) / ethReserve;

// 2. Approve tokens
token.approve(address(liquidityPool), tokenAmount);

// 3. Add liquidity
liquidityPool.addLiquidity{value: ethAmount}(tokenAmount);

// 4. Monitor position
uint256 myLiquidity = liquidityPool.liquidityBalance(address(this));
uint256 totalLiquidity = liquidityPool.totalLiquidity();
uint256 poolShare = (myLiquidity * 100) / totalLiquidity;

// 5. Remove liquidity when ready
liquidityPool.removeLiquidity(myLiquidity);
```

### Trading Flow

```solidity
// 1. ETH to Token Swap
uint256 ethIn = 1 ether;
uint256 minTokens = calculateMinTokensOut(ethIn);
liquidityPool.swapETHForTokens{value: ethIn}(minTokens);

// 2. Token to ETH Swap
uint256 tokensIn = 1000 * 10**18;
uint256 minETH = calculateMinETHOut(tokensIn);
token.approve(address(liquidityPool), tokensIn);
liquidityPool.swapTokensForETH(tokensIn, minETH);
```

## Error Handling

Common errors you might encounter:

```solidity
InsufficientLiquidity()      // Pool lacks liquidity
InsufficientInputAmount()    // Input amount too low
InsufficientOutputAmount()   // Output amount too low
InvalidK()                   // Constant product invariant violated
TransferFailed()            // Token transfer failed
UnbalancedLiquidityRatios() // Liquidity ratios don't match
InsufficientTokenAmount()   // Not enough tokens provided
SlippageExceeded()         // Price moved beyond slippage
EmergencyWithdrawalFailed() // Emergency withdrawal failed
```

## Security Considerations

1. **Slippage Protection**
   - Set appropriate slippage limits
   - Monitor price movements
   - Use maxSlippage parameter

2. **Liquidity Management**
   - Monitor pool share
   - Watch for impermanent loss
   - Consider pool concentration

3. **Trading Safety**
   - Verify output amounts
   - Check price impact
   - Monitor for front-running

4. **Emergency Features**
   - Understand pause mechanism
   - Monitor owner actions
   - Watch for emergency withdrawals

## Integration with Incentives

The LiquidityPool works with LiquidityIncentives contract:

1. Tier updates on liquidity changes
2. Rewards based on liquidity provided
3. Incentive tracking for providers

Remember to:
- Monitor tier status
- Track rewards
- Understand incentive mechanics
