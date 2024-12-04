# Security Controls Settings Documentation

## Rate Limiting Settings

Rate limiting can be configured per operation using `configureRateLimit(bytes32 operation, uint256 limit, uint256 window)`:

- `operation`: Unique identifier for the operation (bytes32 hash)
- `limit`: Maximum number of calls allowed within the time window
- `window`: Time window in seconds
- `currentCount`: Tracks current number of calls (auto-managed)
- `windowStart`: Timestamp when current window started (auto-managed)

Example:
```solidity
_configureRateLimit(WITHDRAWAL, 10, 1 days); // 10 withdrawals per day
```

## Multi-Signature Settings

Multi-sig requirements configured via `configureMultiSig(bytes32 operation, uint256 requiredApprovals, address[] memory approvers)`:

- `operation`: Unique identifier for the operation requiring multi-sig
- `requiredApprovals`: Number of approvals needed to execute
- `approvers`: Array of addresses authorized to approve
- Transaction tracking (auto-managed):
  - `approvals`: Maps transaction hashes to approver addresses
  - `executed`: Tracks which transactions have been executed
  - `approvalCount`: Number of approvals received per transaction

Example:
```solidity
address[] memory approvers = new address[](3);
approvers[0] = address(0x1);
approvers[1] = address(0x2);
approvers[2] = address(0x3);
_configureMultiSig(LARGE_WITHDRAWAL, 2, approvers); // Requires 2 of 3 approvers
```

## Emergency Control Settings

Emergency settings managed through EmergencyConfig struct:

- `circuitBreakerEnabled`: Boolean flag for emergency state
  - Set to true via `triggerEmergency(string reason)`
  - Set to false via `resolveEmergency()`
- `lastEmergencyAction`: Timestamp of last emergency action (auto-managed)
- `cooldownPeriod`: Minimum time between emergency actions
  - Default: 24 hours
  - Configurable via `setEmergencyCooldownPeriod(uint256 cooldownPeriod)`

## Access Control Roles

Built-in roles (managed via OpenZeppelin AccessControl):

- `DEFAULT_ADMIN_ROLE`: Can configure rate limits and multi-sig settings
- `EMERGENCY_ROLE`: Can trigger and resolve emergency states
- `OPERATOR_ROLE`: Basic operational permissions

## Modifiers Available

Security modifiers that can be applied to functions:

- `rateLimitGuard(bytes32 operation)`: Enforces rate limiting
- `requiresApproval(bytes32 operation, bytes32 txHash)`: Requires multi-sig approval
- `whenCircuitBreakerOff()`: Blocks execution during emergency
- `nonReentrant`: Prevents reentrancy attacks (inherited from ReentrancyGuard)
- `whenNotPaused`: Blocks execution when contract is paused (inherited from Pausable)

## Events Emitted

Events for monitoring and tracking:

- `RateLimitConfigured(bytes32 indexed operation, uint256 limit, uint256 window)`
- `RateLimitExceeded(bytes32 indexed operation, address indexed caller)`
- `MultiSigConfigured(bytes32 indexed operation, uint256 requiredApprovals)`
- `MultiSigApproval(bytes32 indexed operation, bytes32 indexed txHash, address indexed approver)`
- `MultiSigExecuted(bytes32 indexed operation, bytes32 indexed txHash)`
- `EmergencyActionTriggered(address indexed triggeredBy, string reason)`
- `EmergencyCooldownUpdated(uint256 newCooldownPeriod)`
- `CircuitBreakerStatusChanged(bool enabled)`
