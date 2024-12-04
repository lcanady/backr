# Governance Contract Tutorial

This tutorial explains how to interact with the Governance contract, which manages the platform's DAO structure, including proposal creation, voting, delegation, and execution.

## Core Concepts

### Proposals
Each proposal contains:
- Description of the proposed action
- Target contract address
- Function call data to execute
- Voting period and results
- Execution status

### Key Parameters
- `VOTING_PERIOD`: 7 days
- `EXECUTION_DELAY`: 2 days
- `PROPOSAL_THRESHOLD`: 100 tokens required to create proposals

## Creating and Managing Proposals

### Creating a Proposal

```solidity
// Example: Create a proposal to call setParam(uint256) on a target contract
bytes memory callData = abi.encodeWithSignature("setParam(uint256)", 123);

governance.createProposal(
    "Update platform parameter to 123",  // description
    targetContractAddress,               // target
    callData                            // function call data
);
```

**Requirements**:
- Must hold at least 100 platform tokens
- Target address must be valid
- Provide valid function call data

### Canceling a Proposal

```solidity
governance.cancelProposal(proposalId);
```

**Notes**:
- Only the proposer or contract owner can cancel
- Must be canceled before voting period ends
- Cannot cancel already executed proposals

## Voting System

### Standard Voting

```solidity
// Vote in favor of a proposal
governance.castVote(proposalId, true);  // true for support, false against
```

### Gasless Voting
Using meta-transactions for gas-free voting:

```solidity
// Create vote permit
VotePermit memory permit = VotePermit({
    voter: voterAddress,
    proposalId: id,
    support: true,
    nonce: nonce,
    deadline: deadline
});

// Sign permit off-chain
bytes memory signature = signPermit(permit);

// Submit vote with permit
governance.castVoteWithPermit(permit, signature);
```

### Checking Proposal Status

```solidity
(
    uint256 forVotes,
    uint256 againstVotes,
    uint256 startTime,
    uint256 endTime,
    bool executed
) = governance.getProposal(proposalId);
```

## Delegation System

### Delegating Voting Power

```solidity
// Delegate voting power to another address
governance.delegate(delegateeAddress);
```

**Important Notes**:
- Cannot delegate to zero address or self
- Automatically updates voting power for active proposals
- Previous delegations are removed when delegating to a new address

### Checking Voting Power

```solidity
// Get total voting power of an address
uint256 power = governance.getVotingPower(address);
```

Voting power includes:
- Own token balance (if not delegated)
- Total amount delegated by others

## Proposal Execution

### Executing Passed Proposals

```solidity
governance.executeProposal(proposalId);
```

**Requirements**:
1. Voting period must be over
2. Proposal must have more support than opposition
3. Must wait for execution delay (2 days) after voting ends
4. Proposal must not be already executed

## Events to Monitor

1. Proposal Lifecycle Events:
   ```solidity
   event ProposalCreated(
       uint256 indexed proposalId,
       address indexed proposer,
       string description,
       uint256 startTime,
       uint256 endTime
   );
   event ProposalExecuted(uint256 indexed proposalId);
   event ProposalCancelled(uint256 indexed proposalId);
   ```

2. Voting Events:
   ```solidity
   event VoteCast(
       address indexed voter,
       uint256 indexed proposalId,
       bool support,
       uint256 weight
   );
   ```

3. Delegation Events:
   ```solidity
   event DelegateChanged(
       address indexed delegator,
       address indexed fromDelegate,
       address indexed toDelegate
   );
   ```

## Best Practices

1. **Proposal Creation**
   - Write clear, detailed descriptions
   - Test call data before submission
   - Consider impact on platform
   - Ensure sufficient token balance

2. **Voting**
   - Review proposal details thoroughly
   - Consider using gasless voting for better UX
   - Check voting power before casting
   - Monitor voting progress

3. **Delegation**
   - Choose delegates carefully
   - Monitor delegate voting patterns
   - Regularly review delegation status
   - Consider impact on active proposals

4. **Execution**
   - Wait for execution delay
   - Verify proposal passed
   - Monitor execution success
   - Have fallback plans for failed execution

## Complete Example

Here's a full example of the governance process:

```solidity
// 1. Create a proposal
bytes memory callData = abi.encodeWithSignature(
    "updateParameter(uint256)",
    newValue
);

governance.createProposal(
    "Update platform parameter",
    targetContract,
    callData
);

// 2. Delegate voting power (optional)
governance.delegate(trustedDelegate);

// 3. Cast votes
governance.castVote(proposalId, true);

// Or use gasless voting
VotePermit memory permit = VotePermit({
    voter: msg.sender,
    proposalId: proposalId,
    support: true,
    nonce: nonce,
    deadline: block.timestamp + 1 hours
});
bytes memory signature = signPermit(permit);
governance.castVoteWithPermit(permit, signature);

// 4. Monitor proposal status
(
    uint256 forVotes,
    uint256 againstVotes,
    uint256 startTime,
    uint256 endTime,
    bool executed
) = governance.getProposal(proposalId);

// 5. Execute proposal after voting period + delay
governance.executeProposal(proposalId);
```

## Security Considerations

1. **Proposal Creation**
   - Verify target contract address
   - Test call data thoroughly
   - Consider impact on platform security

2. **Voting Power**
   - Monitor delegation changes
   - Track voting power snapshots
   - Watch for voting manipulation

3. **Execution**
   - Ensure proper execution delay
   - Verify proposal details before execution
   - Monitor for failed executions

4. **Meta-transactions**
   - Verify signature validity
   - Check permit deadlines
   - Monitor nonce management

## Integration with Committee Governance

The Governance contract works alongside CommitteeGovernance:

1. Committees get specialized voting domains
2. Committee voting power affects proposal outcomes
3. Function-level permissions control what can be proposed

Remember to:
- Consider committee structure in proposals
- Account for voting power multipliers
- Coordinate with committee actions
