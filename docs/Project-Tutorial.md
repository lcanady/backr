# Project Contract Tutorial

This tutorial explains how to interact with the Project contract, which is a core component of the Backr platform for managing project creation, funding, and milestone tracking.

## Prerequisites

- A registered user profile on the Backr platform
- Some ETH for funding projects and gas fees
- Basic understanding of blockchain transactions

## Core Concepts

### Projects
A project consists of:
- Title and description
- A series of milestones
- Funding goals
- Voting requirements for milestone completion

### Milestones
Each milestone includes:
- Description
- Required funding amount
- Required number of votes for completion
- Vote tracking

## Creating a Project

To create a new project, you'll need to prepare:
1. Project title and description
2. List of milestone descriptions
3. Funding requirements for each milestone
4. Required votes for each milestone

```solidity
// Example: Creating a project with 2 milestones
string[] milestoneDescriptions = ["Initial prototype", "Final product"];
uint256[] milestoneFunding = [1 ether, 2 ether];
uint256[] milestoneVotes = [3, 5]; // Votes required for each milestone

project.createProject(
    "My Project",
    "A description of my project",
    milestoneDescriptions,
    milestoneFunding,
    milestoneVotes
);
```

**Note**: You can only create one project per 24 hours due to rate limiting.

## Contributing Funds

You can contribute funds to any active project:

```solidity
// Example: Contributing 1 ETH to project ID 1
project.contributeToProject{value: 1 ether}(1);
```

**Important Security Notes**:
- Contributions over 10 ETH require multi-signature approval
- The circuit breaker must be off to contribute
- The contract must not be paused

## Milestone Voting

Stakeholders can vote on milestone completion:

```solidity
// Example: Voting for milestone 0 of project 1
project.voteMilestone(1, 0);
```

**Key Points**:
- Each address can only vote once per milestone
- When sufficient votes are received, the milestone is marked complete
- Funds are automatically released to the project creator upon completion

## Viewing Project Information

### Getting Milestone Details

```solidity
// Example: Getting details for milestone 0 of project 1
(
    string memory description,
    uint256 fundingRequired,
    uint256 votesRequired,
    uint256 votesReceived,
    bool isCompleted
) = project.getMilestone(1, 0);
```

### Checking Vote Status

```solidity
// Example: Checking if an address has voted
bool hasVoted = project.hasVotedForMilestone(1, 0, voterAddress);
```

## Emergency Features

The contract includes emergency features accessible only to administrators:

- Emergency withdrawal of funds when paused
- Circuit breaker protection
- Rate limiting on critical operations

## Events to Monitor

The contract emits several events you can monitor:

1. `ProjectCreated(uint256 projectId, address creator, string title)`
2. `MilestoneAdded(uint256 projectId, uint256 milestoneId, string description)`
3. `FundsContributed(uint256 projectId, address contributor, uint256 amount)`
4. `MilestoneCompleted(uint256 projectId, uint256 milestoneId)`
5. `FundsReleased(uint256 projectId, uint256 milestoneId, uint256 amount)`

## Best Practices

1. **Project Creation**
   - Ensure milestone descriptions are clear and specific
   - Set reasonable funding requirements
   - Choose appropriate voting thresholds

2. **Contributing**
   - Verify project details before contributing
   - Be aware of large funding thresholds
   - Check project status and milestone progress

3. **Milestone Voting**
   - Review milestone deliverables before voting
   - Verify milestone completion criteria
   - Check current vote counts

## Error Handling

Common errors you might encounter:

- `UserNotRegistered`: Ensure you have a registered profile
- `InvalidProjectParameters`: Check all project parameters are valid
- `ProjectNotFound`: Verify the project ID exists
- `InsufficientFunds`: Ensure adequate funds for contribution
- `MilestoneNotFound`: Verify milestone ID exists
- `AlreadyVoted`: Each address can only vote once
- `MilestoneAlreadyCompleted`: Cannot vote on completed milestones
- `InsufficientVotes`: Milestone needs more votes for completion

## Testing Example

Here's a complete example of creating and interacting with a project:

```solidity
// 1. Create a project
string[] memory descriptions = new string[](2);
descriptions[0] = "Build MVP";
descriptions[1] = "Launch Product";

uint256[] memory funding = new uint256[](2);
funding[0] = 1 ether;
funding[1] = 2 ether;

uint256[] memory votes = new uint256[](2);
votes[0] = 3;
votes[1] = 5;

project.createProject(
    "My DApp",
    "A decentralized application",
    descriptions,
    funding,
    votes
);

// 2. Contribute funds
project.contributeToProject{value: 1.5 ether}(0);

// 3. Vote on milestone
project.voteMilestone(0, 0);

// 4. Check milestone status
(
    string memory desc,
    uint256 fundingReq,
    uint256 votesReq,
    uint256 votesRec,
    bool completed
) = project.getMilestone(0, 0);
```

## Security Considerations

1. **Rate Limiting**
   - Project creation: 1 per 24 hours
   - Milestone completions: 10 per day

2. **Multi-Signature Requirements**
   - Large funding operations (≥10 ETH) require approval
   - Emergency operations require proper roles

3. **Circuit Breaker**
   - Protects against potential vulnerabilities
   - Affects funding and voting operations

4. **Access Control**
   - Emergency functions restricted to admin roles
   - Proper role management is crucial
