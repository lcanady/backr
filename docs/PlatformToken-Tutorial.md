# PlatformToken Contract Tutorial

The PlatformToken contract implements the platform's native ERC20 token (BACKR) with built-in staking and reward mechanisms to incentivize long-term platform participation.

## Core Features

1. ERC20 Token Implementation
2. Token Staking System
3. Automatic Reward Generation
4. Owner-controlled Token Minting

## Token Economics

### Initial Supply
- 1 million BACKR tokens (1,000,000 * 10^18)
- Minted to contract deployer
- Additional minting controlled by owner

### Staking Parameters
- Minimum Stake Duration: 7 days
- Annual Reward Rate: 5%
- No maximum staking limit
- Rewards calculated based on time and amount staked

## Token Management

### Minting New Tokens

Only the contract owner can mint additional tokens:

```solidity
function mint(address to, uint256 amount) external onlyOwner
```

Example usage:
```solidity
// Mint 1000 tokens to an address
platformToken.mint(
    recipientAddress,
    1000 * 10**18 // Amount with 18 decimals
);
```

### Basic Token Operations

Standard ERC20 operations are available:

```solidity
// Transfer tokens
function transfer(address to, uint256 amount) external returns (bool)

// Approve spending
function approve(address spender, uint256 amount) external returns (bool)

// Transfer from approved amount
function transferFrom(address from, address to, uint256 amount) external returns (bool)
```

## Staking System

### Staking Tokens

Users can stake their tokens for rewards:

```solidity
function stake(uint256 amount) external
```

Example usage:
```solidity
// Stake 100 tokens
platformToken.stake(100 * 10**18);
```

**Requirements**:
- Amount must be greater than 0
- User must have sufficient balance
- Tokens are transferred to contract during stake

### Unstaking Tokens

Users can unstake their tokens and claim rewards:

```solidity
function unstake() external
```

**Important Notes**:
- Must have staked tokens
- Must meet minimum stake duration (7 days)
- Receives original stake plus rewards
- Staking position is cleared after unstaking

### Viewing Stake Information

Get current staking details for an address:

```solidity
function getStakeInfo(address account) external view returns (
    uint256 amount,
    uint256 since,
    uint256 reward
)
```

Example usage:
```solidity
// Get stake info
(uint256 amount, uint256 since, uint256 reward) = platformToken.getStakeInfo(userAddress);
```

## Reward Calculation

### Formula

Rewards are calculated using the following formula:
```
reward = (staked_amount * rate * time) / (365 days * 100)
```

Where:
- staked_amount: Amount of tokens staked
- rate: 5 (5% annual rate)
- time: Duration since stake (in seconds)

### Calculating Rewards

View current reward for an address:

```solidity
function calculateReward(address account) public view returns (uint256)
```

Example usage:
```solidity
// Get current reward amount
uint256 reward = platformToken.calculateReward(userAddress);
```

## Integration Example

Here's a complete example of integrating the token and staking system:

```solidity
contract PlatformCore {
    PlatformToken public token;
    
    function stakePlatformTokens(uint256 amount) external {
        // First approve token transfer
        require(token.approve(address(token), amount), "Approve failed");
        
        // Stake tokens
        try token.stake(amount) {
            // Staking successful
            emit TokensStaked(msg.sender, amount);
        } catch Error(string memory reason) {
            // Handle staking failure
            revert(string(abi.encodePacked("Stake failed: ", reason)));
        }
    }
    
    function unstakePlatformTokens() external {
        // Unstake and get rewards
        try token.unstake() {
            // Get updated balance
            uint256 newBalance = token.balanceOf(msg.sender);
            emit TokensUnstaked(msg.sender, newBalance);
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Unstake failed: ", reason)));
        }
    }
}
```

## Events

Monitor token and staking activities:

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);
event Staked(address indexed user, uint256 amount);
event Unstaked(address indexed user, uint256 amount, uint256 reward);
```

## Best Practices

1. **Token Management**
   - Always use SafeMath operations (built into Solidity 0.8+)
   - Check balances before operations
   - Use proper decimal handling (18 decimals)

2. **Staking**
   - Verify minimum stake duration
   - Consider gas costs for large numbers
   - Monitor staking events

3. **Rewards**
   - Regular monitoring of reward calculations
   - Consider economic implications of reward rate
   - Track total rewards distributed

4. **Security**
   - Implement access controls for admin functions
   - Regular audits of token distribution
   - Monitor for unusual activity

## Testing Example

Here's how to test the token and staking system:

```solidity
contract PlatformTokenTest is Test {
    PlatformToken public token;
    address user = address(0x1);
    
    function setUp() public {
        token = new PlatformToken();
        token.transfer(user, 1000 * 10**18); // Give user some tokens
    }
    
    function testStaking() public {
        vm.startPrank(user);
        
        // Stake tokens
        uint256 stakeAmount = 100 * 10**18;
        token.stake(stakeAmount);
        
        // Check stake info
        (uint256 amount, uint256 since, ) = token.getStakeInfo(user);
        assertEq(amount, stakeAmount);
        assertEq(since, block.timestamp);
        
        // Fast forward 7 days
        vm.warp(block.timestamp + 7 days);
        
        // Calculate expected reward
        uint256 expectedReward = (stakeAmount * 5 * 7 days) / (365 days * 100);
        uint256 actualReward = token.calculateReward(user);
        assertEq(actualReward, expectedReward);
        
        // Unstake and verify reward
        uint256 balanceBefore = token.balanceOf(user);
        token.unstake();
        uint256 balanceAfter = token.balanceOf(user);
        assertEq(balanceAfter, balanceBefore + stakeAmount + expectedReward);
        
        vm.stopPrank();
    }
}
```

## Security Considerations

1. **Access Control**
   - Minting restricted to owner
   - Staking/unstaking open to all users
   - No admin control over user stakes

2. **Economic Security**
   - Fixed reward rate
   - Minimum stake duration
   - No maximum supply cap (controlled by owner)

3. **Smart Contract Security**
   - OpenZeppelin base contracts
   - Reentrancy protection (CEI pattern)
   - Integer overflow protection (Solidity 0.8+)

4. **Operational Security**
   - Event emission for tracking
   - View functions for transparency
   - Clear error messages
