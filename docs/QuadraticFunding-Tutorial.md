# Quadratic Funding Tutorial

This tutorial explains how to use the QuadraticFunding contract, which implements a quadratic funding mechanism for distributing matching funds to projects on the Backr platform.

## Core Concepts

### Funding Rounds
Each funding round has:
- Start and end time
- Matching pool
- Contribution limits (min/max)
- Project contributions tracking
- Participant eligibility

### Quadratic Funding
The matching amount for each project is calculated based on the square root of contributions, giving more weight to multiple small contributions over fewer large ones.

## Managing Funding Rounds

### Creating a New Round

```solidity
// Round configuration
RoundConfig memory config = RoundConfig({
    startTime: block.timestamp + 1 days,
    endTime: block.timestamp + 15 days,
    minContribution: 0.1 ether,
    maxContribution: 10 ether
});

// Create round with initial matching pool
quadraticFunding.createRound{value: 100 ether}(config);
```

**Requirements**:
- Only admins can create rounds
- Must include initial matching pool funds
- Valid time period (end > start)
- Valid contribution limits (max > min)

### Contributing to Matching Pool

```solidity
// Add more funds to matching pool
quadraticFunding.contributeToMatchingPool{value: 50 ether}(roundId);
```

### Managing Participant Eligibility

```solidity
// Verify participant eligibility
quadraticFunding.verifyParticipant(participantAddress, true);
```

## Contributing to Projects

### Making Contributions

```solidity
// Contribute to a project
quadraticFunding.contribute{value: 1 ether}(projectId);
```

**Requirements**:
- Active round
- Eligible participant
- Contribution within min/max limits
- Round not cancelled

### Checking Contribution Status

```solidity
// Get total contributions for a project
uint256 total = quadraticFunding.getProjectContributions(roundId, projectId);

// Get individual contribution
uint256 amount = quadraticFunding.getContribution(
    roundId,
    projectId,
    contributorAddress
);
```

## Round Management

### Checking Round Status

```solidity
// Check if round is active
bool active = quadraticFunding.isRoundActive();
```

### Cancelling a Round

```solidity
// Only admins can cancel rounds
quadraticFunding.cancelRound();
```

### Finalizing a Round

```solidity
// Calculate and distribute matching funds
quadraticFunding.finalizeRound();
```

**Important Notes**:
- Round must be ended
- Cannot be already finalized
- Must have contributions
- Not cancelled

## Analytics

### Viewing Round Analytics

```solidity
// Get round statistics
RoundAnalytics memory analytics = quadraticFunding.getRoundAnalytics(roundId);

// Analytics include:
// - Unique contributors
// - Total projects
// - Average contribution
// - Median contribution
```

## Events to Monitor

1. Round Lifecycle Events:
   ```solidity
   event RoundStarted(uint256 indexed roundId, uint256 matchingPool);
   event RoundFinalized(uint256 indexed roundId, uint256 totalMatching);
   event RoundCancelledEvent(uint256 indexed roundId);
   event RoundConfigured(
       uint256 indexed roundId,
       uint256 startTime,
       uint256 endTime,
       uint256 minContribution,
       uint256 maxContribution
   );
   ```

2. Contribution Events:
   ```solidity
   event ContributionAdded(
       uint256 indexed roundId,
       uint256 indexed projectId,
       address indexed contributor,
       uint256 amount
   );
   event MatchingPoolContribution(
       uint256 indexed roundId,
       address indexed contributor,
       uint256 amount
   );
   event MatchingFundsDistributed(
       uint256 indexed roundId,
       uint256 indexed projectId,
       uint256 amount
   );
   ```

3. Participant Management:
   ```solidity
   event ParticipantVerified(
       address indexed participant,
       bool eligible
   );
   ```

## Understanding Matching Calculations

The matching amount for each project is calculated using the quadratic funding formula:

1. Calculate square root of each project's total contributions
2. Sum all square roots
3. Distribute matching pool proportionally based on square root ratios

Example:
```
Project A: 100 ETH from 1 contributor
Project B: 100 ETH from 100 contributors

Square root calculation:
A = √100 = 10
B = √(1² × 100) = √100 = 10

Despite same total, they receive equal matching because B had more contributors
```

## Best Practices

1. **Round Creation**
   - Set appropriate duration (default 14 days)
   - Consider contribution limits carefully
   - Ensure sufficient matching pool

2. **Participant Management**
   - Verify participants before round starts
   - Document verification criteria
   - Monitor eligibility status

3. **Contribution Handling**
   - Monitor contribution patterns
   - Track matching pool size
   - Consider gas costs

4. **Round Finalization**
   - Wait for round completion
   - Verify all contributions processed
   - Monitor matching distribution

## Complete Example

Here's a full example of managing a funding round:

```solidity
// 1. Create new round
RoundConfig memory config = RoundConfig({
    startTime: block.timestamp + 1 days,
    endTime: block.timestamp + 15 days,
    minContribution: 0.1 ether,
    maxContribution: 10 ether
});

quadraticFunding.createRound{value: 100 ether}(config);

// 2. Verify participants
address[] memory participants = getEligibleParticipants();
for (uint i = 0; i < participants.length; i++) {
    quadraticFunding.verifyParticipant(participants[i], true);
}

// 3. Accept contributions during round
// (from participant perspective)
quadraticFunding.contribute{value: 1 ether}(projectId);

// 4. Monitor round progress
RoundAnalytics memory analytics = quadraticFunding.getRoundAnalytics(
    currentRound
);

// 5. Finalize round after end
if (block.timestamp > config.endTime) {
    quadraticFunding.finalizeRound();
}

// 6. Check matching results
uint256 matching = quadraticFunding.getMatchingAmount(
    currentRound,
    projectId
);
```

## Security Considerations

1. **Round Management**
   - Verify round parameters
   - Monitor matching pool
   - Handle cancellations properly

2. **Contribution Validation**
   - Check eligibility
   - Verify contribution limits
   - Monitor for manipulation

3. **Matching Distribution**
   - Verify calculations
   - Monitor fund transfers
   - Handle edge cases

4. **Analytics**
   - Track unusual patterns
   - Monitor for gaming attempts
   - Validate statistics

## Error Handling

Common errors you might encounter:

```solidity
RoundNotActive()           // Round hasn't started or has ended
RoundAlreadyActive()       // Cannot start new round while one is active
InsufficientContribution() // Contribution below minimum
RoundNotEnded()           // Cannot finalize active round
RoundAlreadyFinalized()   // Round already completed
NoContributions()         // No contributions to process
MatchingPoolEmpty()       // No matching funds available
RoundCancelledError()     // Round was cancelled
UnauthorizedAdmin()       // Not an admin
ContributionTooLow()      // Below minimum contribution
ContributionTooHigh()     // Above maximum contribution
ParticipantNotEligible()  // Contributor not verified
InvalidRoundConfig()      // Invalid round parameters
