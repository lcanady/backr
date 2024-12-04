# SecurityControls Contract Tutorial

The SecurityControls contract is a comprehensive security management system for Solidity smart contracts that implements three core security features:
1. Rate Limiting
2. Multi-signature Requirements
3. Emergency Controls

> **Note**: For a complete list of all available settings and configurations, see [SecurityControls-Settings.md](SecurityControls-Settings.md)

## Overview

The contract inherits from three OpenZeppelin contracts:
- `AccessControl`: For role-based access control
- `Pausable`: For emergency pause functionality
- `ReentrancyGuard`: For protection against reentrancy attacks

## Key Features

### 1. Rate Limiting

Rate limiting prevents excessive calls to specific operations within a time window. This is useful for protecting against spam attacks or resource exhaustion.

```solidity
// Configure rate limiting for an operation
function configureRateLimit(
    bytes32 operation,
    uint256 limit,
    uint256 window
) external onlyRole(DEFAULT_ADMIN_ROLE)

// Usage example:
contract MyContract is SecurityControls {
    bytes32 public constant WITHDRAW_OPERATION = keccak256("WITHDRAW");
    
    function setUp() {
        // Allow 5 withdrawals per day
        configureRateLimit(WITHDRAW_OPERATION, 5, 1 days);
    }
    
    function withdraw() external rateLimitGuard(WITHDRAW_OPERATION) {
        // Withdrawal logic here
    }
}
```

### 2. Multi-signature Requirements

Multi-sig functionality requires multiple approvers to sign off on sensitive operations before they can be executed.

```solidity
// Configure multi-sig requirements
function configureMultiSig(
    bytes32 operation,
    uint256 requiredApprovals,
    address[] memory approvers
) public onlyRole(DEFAULT_ADMIN_ROLE)

// Usage example:
contract MyContract is SecurityControls {
    bytes32 public constant LARGE_TRANSFER = keccak256("LARGE_TRANSFER");
    bytes32 public transferTxHash;
    
    function setUp() {
        address[] memory approvers = new address[](3);
        approvers[0] = address(0x1); // Replace with actual addresses
        approvers[1] = address(0x2);
        approvers[2] = address(0x3);
        
        // Require 2 out of 3 approvals
        configureMultiSig(LARGE_TRANSFER, 2, approvers);
    }
    
    function initiateTransfer() external requiresApproval(LARGE_TRANSFER, transferTxHash) {
        // Transfer logic here
    }
}
```

### 3. Emergency Controls

Emergency controls provide circuit breaker functionality and cool-down periods for crisis management.

```solidity
// Trigger emergency mode
function triggerEmergency(string calldata reason) external onlyRole(EMERGENCY_ROLE)

// Resolve emergency
function resolveEmergency() external onlyRole(EMERGENCY_ROLE)

// Usage example:
contract MyContract is SecurityControls {
    function criticalOperation() external whenCircuitBreakerOff {
        // Critical operation logic here
    }
}
```

## Role-Based Access Control

The contract defines three main roles:
1. `DEFAULT_ADMIN_ROLE`: Can configure rate limits and multi-sig requirements
2. `EMERGENCY_ROLE`: Can trigger and resolve emergency situations
3. `OPERATOR_ROLE`: For day-to-day operations

```solidity
// Granting roles
contract MyContract is SecurityControls {
    function setUp() {
        _grantRole(EMERGENCY_ROLE, emergencyAdmin);
        _grantRole(OPERATOR_ROLE, operator);
    }
}
```

## Best Practices

1. **Rate Limiting**
   - Set appropriate limits based on expected legitimate usage
   - Consider different time windows for different operations
   - Monitor rate limit hits to detect potential attacks

2. **Multi-signature**
   - Choose an appropriate number of required approvals
   - Maintain a diverse set of approvers
   - Consider the operational impact of required approvals

3. **Emergency Controls**
   - Limit emergency role access to trusted entities
   - Have clear procedures for emergency situations
   - Test emergency procedures regularly
   - Set appropriate cooldown periods

## Events

The contract emits various events for monitoring and auditing:

```solidity
event RateLimitConfigured(bytes32 indexed operation, uint256 limit, uint256 window);
event RateLimitExceeded(bytes32 indexed operation, address indexed caller);
event MultiSigConfigured(bytes32 indexed operation, uint256 requiredApprovals);
event MultiSigApproval(bytes32 indexed operation, bytes32 indexed txHash, address indexed approver);
event MultiSigExecuted(bytes32 indexed operation, bytes32 indexed txHash);
event EmergencyActionTriggered(address indexed triggeredBy, string reason);
event EmergencyCooldownUpdated(uint256 newCooldownPeriod);
event CircuitBreakerStatusChanged(bool enabled);
```

## Testing

Here's an example of how to test the security controls:

```solidity
contract SecurityControlsTest is Test {
    SecurityControls public securityControls;
    
    function setUp() public {
        securityControls = new SecurityControls();
    }
    
    function testRateLimit() public {
        // Configure rate limit
        securityControls.configureRateLimit(
            keccak256("TEST_OP"),
            2,  // 2 calls allowed
            1 hours  // per hour
        );
        
        // First two calls should succeed
        rateLimitedOperation();
        rateLimitedOperation();
        
        // Third call should fail
        vm.expectRevert("Rate limit exceeded");
        rateLimitedOperation();
        
        // After time window, should work again
        vm.warp(block.timestamp + 1 hours + 1);
        rateLimitedOperation();
    }
}
```

## Integration Example

Here's a complete example of integrating SecurityControls into a contract:

```solidity
contract SecureVault is SecurityControls {
    bytes32 public constant WITHDRAWAL = keccak256("WITHDRAWAL");
    bytes32 public constant LARGE_WITHDRAWAL = keccak256("LARGE_WITHDRAWAL");
    
    uint256 public constant LARGE_AMOUNT = 100 ether;
    
    constructor() {
        // Configure rate limiting
        _configureRateLimit(WITHDRAWAL, 10, 1 days);  // 10 withdrawals per day
        
        // Configure multi-sig for large withdrawals
        address[] memory approvers = new address[](3);
        approvers[0] = address(0x1);  // Replace with actual addresses
        approvers[1] = address(0x2);
        approvers[2] = address(0x3);
        _configureMultiSig(LARGE_WITHDRAWAL, 2, approvers);
    }
    
    function withdraw(uint256 amount) external 
        rateLimitGuard(WITHDRAWAL)
        whenCircuitBreakerOff 
    {
        require(amount < LARGE_AMOUNT, "Use largeWithdraw for large amounts");
        // Withdrawal logic
    }
    
    function largeWithdraw(uint256 amount, bytes32 txHash) external 
        requiresApproval(LARGE_WITHDRAWAL, txHash)
        whenCircuitBreakerOff 
    {
        require(amount >= LARGE_AMOUNT, "Use regular withdraw for small amounts");
        // Large withdrawal logic
    }
}
```

## Security Considerations

1. **Rate Limiting**
   - Ensure rate limits are set appropriately for your use case
   - Consider the impact of rate limits on legitimate users
   - Monitor rate limit events to detect potential attacks

2. **Multi-signature**
   - Choose approvers carefully and maintain their list
   - Consider the operational impact of required approvals
   - Implement proper transaction hash generation and verification

3. **Emergency Controls**
   - Have clear procedures for emergency situations
   - Test emergency procedures regularly
   - Monitor emergency events
   - Consider the impact of pausing on dependent contracts

4. **Access Control**
   - Carefully manage role assignments
   - Regularly audit role holders
   - Consider implementing role rotation procedures

## Conclusion

The SecurityControls contract provides a robust security framework for your smart contracts. By properly implementing rate limiting, multi-signature requirements, and emergency controls, you can significantly enhance the security of your smart contract system.

Remember to:
- Thoroughly test all security features
- Monitor security events
- Maintain proper access control
- Have clear procedures for emergency situations
- Regularly review and update security parameters
