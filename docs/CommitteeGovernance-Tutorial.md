# Committee Governance Tutorial

This tutorial explains how to use the CommitteeGovernance contract, which manages specialized committees with their own voting domains in the Backr platform.

## Overview

The CommitteeGovernance system allows for:
- Creation of specialized committees
- Management of committee membership
- Control of committee voting powers
- Function-level permissions for proposals

## Core Concepts

### Committees
Each committee has:
- Name and description
- Voting power multiplier (in basis points)
- Active status
- Member list
- Allowed functions list

### Roles
- `DEFAULT_ADMIN_ROLE`: Overall contract administration
- `COMMITTEE_ADMIN_ROLE`: Committee management permissions

## Creating and Managing Committees

### Creating a Committee

```solidity
function createCommittee(
    "Technical Review",                  // name
    "Reviews technical implementations", // description
    500                                 // votingPowerMultiplier (5x)
)
```

**Important Notes**:
- Only addresses with `COMMITTEE_ADMIN_ROLE` can create committees
- Voting power multiplier is in basis points (100 = 1x, 1000 = 10x)
- Maximum multiplier is 10000 (100x)

### Managing Committee Members

Adding members:
```solidity
// Add a member to committee ID 0
committeeGovernance.addMember(0, memberAddress);
```

Removing members:
```solidity
// Remove a member from committee ID 0
committeeGovernance.removeMember(0, memberAddress);
```

**Requirements**:
- Only `COMMITTEE_ADMIN_ROLE` can add/remove members
- Committee must exist
- Cannot add existing members
- Cannot remove non-members

### Managing Function Permissions

Allow functions for committee proposals:
```solidity
// Allow a function for committee ID 0
bytes4 functionSelector = bytes4(keccak256("functionName(paramTypes)"));
committeeGovernance.allowFunction(0, functionSelector);
```

## Querying Committee Information

### Check Committee Membership

```solidity
// Check if an address is a committee member
bool isMember = committeeGovernance.isMember(
    0,              // committeeId
    memberAddress   // address to check
);
```

### Get Voting Power Multiplier

```solidity
// Get member's voting power multiplier
uint256 multiplier = committeeGovernance.getVotingPowerMultiplier(
    0,              // committeeId
    memberAddress   // member address
);
```

### Check Function Permissions

```solidity
// Check if a function can be proposed by a committee
bool isAllowed = committeeGovernance.isFunctionAllowed(
    0,                                                  // committeeId
    bytes4(keccak256("functionName(paramTypes)"))      // functionSelector
);
```

## Events to Monitor

The contract emits several important events:

1. `CommitteeCreated(uint256 committeeId, string name)`
   - Triggered when a new committee is created
   - Includes committee ID and name

2. `MemberAdded(uint256 committeeId, address member)`
   - Triggered when a member is added to a committee
   - Includes committee ID and member address

3. `MemberRemoved(uint256 committeeId, address member)`
   - Triggered when a member is removed from a committee
   - Includes committee ID and member address

4. `FunctionAllowed(uint256 committeeId, bytes4 functionSelector)`
   - Triggered when a function is allowed for a committee
   - Includes committee ID and function selector

## Best Practices

1. **Committee Creation**
   - Use descriptive names and clear descriptions
   - Set appropriate voting power multipliers
   - Document committee purposes and responsibilities

2. **Member Management**
   - Regularly review committee membership
   - Maintain appropriate committee sizes
   - Document member selection criteria

3. **Function Permissions**
   - Carefully review functions before allowing
   - Document allowed functions for each committee
   - Regularly audit function permissions

4. **Voting Power**
   - Set multipliers based on committee importance
   - Consider impact on overall governance
   - Document multiplier rationale

## Testing Example

Here's a complete example of setting up and managing a committee:

```solidity
// 1. Create a technical committee
committeeGovernance.createCommittee(
    "Technical Committee",
    "Reviews and approves technical implementations",
    500  // 5x voting power
);

// 2. Add committee members
address[] memory technicalExperts = [
    address(0x123...),
    address(0x456...),
    address(0x789...)
];

for (uint i = 0; i < technicalExperts.length; i++) {
    committeeGovernance.addMember(0, technicalExperts[i]);
}

// 3. Allow specific functions
bytes4[] memory allowedFunctions = [
    bytes4(keccak256("upgradeContract(address)")),
    bytes4(keccak256("setTechnicalParameters(uint256)"))
];

for (uint i = 0; i < allowedFunctions.length; i++) {
    committeeGovernance.allowFunction(0, allowedFunctions[i]);
}

// 4. Verify setup
bool isMember = committeeGovernance.isMember(0, technicalExperts[0]);
uint256 multiplier = committeeGovernance.getVotingPowerMultiplier(0, technicalExperts[0]);
bool canPropose = committeeGovernance.isFunctionAllowed(0, allowedFunctions[0]);
```

## Security Considerations

1. **Role Management**
   - Carefully manage admin role assignments
   - Regularly audit role holders
   - Use multi-sig for admin actions

2. **Voting Power**
   - Consider impact of multipliers on governance
   - Monitor for potential voting power concentration
   - Regular review of multiplier settings

3. **Function Permissions**
   - Audit allowed functions regularly
   - Consider function dependencies
   - Document permission changes

4. **Committee Structure**
   - Maintain appropriate committee sizes
   - Regular review of committee effectiveness
   - Document committee changes

## Integration with Governance

The CommitteeGovernance contract works in conjunction with the main Governance contract:

1. Committee members get voting power multipliers for their domain
2. Proposals for allowed functions can be made by committee members
3. Committee structure provides specialized governance domains

Remember to:
- Coordinate committee actions with main governance
- Consider overall governance impact
- Document committee-governance interactions
