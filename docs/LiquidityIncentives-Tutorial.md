# Liquidity Incentives Tutorial

This tutorial explains how to interact with the LiquidityIncentives contract, which manages liquidity provider tiers, yield farming, and flash loans on the Backr platform.

## Core Concepts

### Tier System
- Three tiers with increasing benefits
- Based on liquidity provided
- Affects reward multipliers and flash loan fees

### Yield Farming
- Multiple staking pools
- Time-based rewards
- Customizable reward rates

### Flash Loans
- Tier-based access
- Variable fees based on tier
- Instant borrowing and repayment

## Tier System

### Tier Levels and Benefits

```solidity
// Tier 1
- Minimum Liquidity: 0.001 tokens
- Reward Multiplier: 1x
- Flash Loan Fee: 0.3%

// Tier 2
- Minimum Liquidity: 0.01 tokens
- Reward Multiplier: 1.5x
- Flash Loan Fee: 0.25%

// Tier 3
- Minimum Liquidity: 0.1 tokens
- Reward Multiplier: 2x
- Flash Loan Fee: 0.2%
```

### Checking Tier Status

```solidity
// Get user's current tier
uint256 tier = liquidityIncentives.userTiers(userAddress);

// Get tier details
(uint256 minLiquidity, uint256 rewardMultiplier, uint256 flashLoanFee, bool enabled) = 
    liquidityIncentives.tiers(tierLevel);
```

## Yield Farming

### Creating a Pool

```solidity
// Only owner can create pools
liquidityIncentives.createPool(
    1,              // poolId
    100000000      // rewardRate (tokens per second)
);
```

### Staking Tokens

```solidity
// First approve tokens
token.approve(liquidityIncentives, amount);

// Stake tokens in pool
liquidityIncentives.stake(poolId, amount);
```

### Managing Stakes

```solidity
// Unstake tokens
liquidityIncentives.unstake(poolId, amount);

// Claim rewards
liquidityIncentives.claimRewards(poolId);

// Check pending rewards
uint256 pending = liquidityIncentives.calculatePendingRewards(poolId, userAddress);
```

## Flash Loans

### Taking a Flash Loan

```solidity
// Implement flash loan receiver interface
contract MyContract is IFlashLoanReceiver {
    function executeOperation(
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override {
        // Use borrowed funds here
        
        // Ensure repayment
        token.transfer(msg.sender, amount + fee);
    }
}

// Request flash loan
liquidityIncentives.flashLoan(
    amount,
    abi.encode(/* your parameters */)
);
```

### Flash Loan Requirements
1. Must have active tier
2. Sufficient contract balance
3. Complete repayment in same transaction
4. Pay tier-based fee

## Events to Monitor

1. Tier Events:
   ```solidity
   event TierUpdated(
       uint256 tierId,
       uint256 minLiquidity,
       uint256 rewardMultiplier,
       uint256 flashLoanFee
   );
   event UserTierChanged(
       address indexed user,
       uint256 oldTier,
       uint256 newTier
   );
   ```

2. Yield Farming Events:
   ```solidity
   event PoolCreated(uint256 poolId, uint256 rewardRate);
   event Staked(address indexed user, uint256 poolId, uint256 amount);
   event Unstaked(address indexed user, uint256 poolId, uint256 amount);
   event RewardsClaimed(address indexed user, uint256 poolId, uint256 amount);
   ```

3. Flash Loan Events:
   ```solidity
   event FlashLoanTaken(
       address indexed borrower,
       uint256 amount,
       uint256 fee
   );
   event FlashLoanRepaid(
       address indexed borrower,
       uint256 amount,
       uint256 fee
   );
   ```

## Best Practices

1. **Tier Management**
   - Monitor liquidity levels
   - Track tier changes
   - Understand benefits
   - Plan for upgrades

2. **Yield Farming**
   - Calculate optimal staking
   - Monitor reward rates
   - Time claims efficiently
   - Consider gas costs

3. **Flash Loans**
   - Verify tier status
   - Calculate fees accurately
   - Ensure repayment
   - Handle failures gracefully

## Complete Examples

### Yield Farming Strategy

```solidity
// Complete yield farming flow
contract YieldFarmingStrategy {
    LiquidityIncentives public incentives;
    PlatformToken public token;
    
    constructor(address _incentives, address _token) {
        incentives = LiquidityIncentives(_incentives);
        token = PlatformToken(_token);
    }
    
    function startFarming(uint256 poolId, uint256 amount) external {
        // 1. Approve tokens
        token.approve(address(incentives), amount);
        
        // 2. Stake in pool
        incentives.stake(poolId, amount);
        
        // 3. Monitor rewards
        uint256 pending = incentives.calculatePendingRewards(
            poolId,
            address(this)
        );
        
        // 4. Claim when profitable
        if (pending > getGasCost()) {
            incentives.claimRewards(poolId);
        }
    }
}
```

### Flash Loan Implementation

```solidity
contract FlashLoanExample is IFlashLoanReceiver {
    LiquidityIncentives public incentives;
    PlatformToken public token;
    
    constructor(address _incentives, address _token) {
        incentives = LiquidityIncentives(_incentives);
        token = PlatformToken(_token);
    }
    
    function executeFlashLoan(uint256 amount) external {
        // 1. Request flash loan
        incentives.flashLoan(
            amount,
            abi.encode("Example")
        );
    }
    
    function executeOperation(
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override {
        // 2. Use funds
        // ... your arbitrage or other logic here ...
        
        // 3. Repay loan
        uint256 repayAmount = amount + fee;
        require(
            token.transfer(msg.sender, repayAmount),
            "Repayment failed"
        );
    }
}
```

## Error Handling

Common errors you might encounter:

```solidity
InvalidTier()               // Invalid tier parameters
InvalidPool()              // Pool doesn't exist
PoolNotActive()            // Pool is not accepting stakes
InsufficientBalance()      // Not enough tokens
FlashLoanActive()          // Another loan in progress
UnauthorizedFlashLoan()    // Not eligible for flash loans
FlashLoanRepaymentFailed() // Repayment unsuccessful
```

## Security Considerations

1. **Tier System**
   - Verify tier updates
   - Monitor threshold changes
   - Track user eligibility

2. **Yield Farming**
   - Check reward calculations
   - Monitor pool balances
   - Verify staking amounts
   - Track reward distribution

3. **Flash Loans**
   - Validate borrower eligibility
   - Ensure proper repayment
   - Monitor loan usage
   - Track fee collection

4. **General Security**
   - Monitor contract state
   - Watch for paused status
   - Track owner actions
   - Verify calculations

## Integration with LiquidityPool

The LiquidityIncentives contract works closely with the LiquidityPool:

1. Automatic tier updates based on liquidity
2. Reward multipliers affect earnings
3. Flash loan access tied to liquidity
4. Pool state affects incentives

Remember to:
- Monitor both contracts
- Understand interactions
- Track state changes
- Coordinate operations
