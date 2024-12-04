# TeamManagement Contract Tutorial

The TeamManagement contract provides a comprehensive system for managing project teams, roles, and delegations. It enables structured team organization and flexible delegation of responsibilities.

## Core Features

1. Team Member Management
2. Role-based Access
3. Delegation System
4. Team Queries

## Team Roles

The system supports four hierarchical roles:

1. **Owner**
   - Highest level of access
   - Full project control
   - Team management rights

2. **Admin**
   - Administrative privileges
   - Team management
   - Project configuration

3. **Member**
   - Standard team access
   - Project participation
   - Basic permissions

4. **Viewer**
   - Read-only access
   - Limited interaction
   - Project observation

## Team Structure

### Team Members

Each team member has:
- Ethereum Address
- Name
- Email
- Role
- Active Status

### Delegations

Delegation records include:
- Delegator Address
- Delegatee Address
- Validity Period
- Active Status

## Core Functions

### Managing Team Members

Add new team members:

```solidity
function addTeamMember(
    address project,
    address member,
    string memory name,
    string memory email,
    TeamRole role
) public
```

Example usage:
```solidity
teamManagement.addTeamMember(
    projectAddress,
    memberAddress,
    "John Doe",
    "john@example.com",
    TeamManagement.TeamRole.Member
);
```

### Managing Delegations

Create and manage delegations:

```solidity
// Create delegation
function createDelegation(
    address delegatee,
    uint256 validUntil
) public

// Revoke delegation
function revokeDelegation() public
```

Example usage:
```solidity
// Create a 30-day delegation
uint256 validUntil = block.timestamp + 30 days;
teamManagement.createDelegation(delegateeAddress, validUntil);

// Later, revoke the delegation
teamManagement.revokeDelegation();
```

### Querying Team Information

Get team and delegation information:

```solidity
// Get team members
function getProjectTeamMembers(address project)
    public
    view
    returns (TeamMember[] memory)

// Check delegation status
function isDelegationActive(address delegator)
    public
    view
    returns (bool)

// Get current delegatee
function getDelegatee(address delegator)
    public
    view
    returns (address)
```

## Integration Example

Here's a complete example of team management:

```solidity
contract ProjectCoordinator {
    TeamManagement public teamManagement;
    
    function setupProjectTeam(address project) external {
        // Add project owner
        teamManagement.addTeamMember(
            project,
            msg.sender,
            "Project Lead",
            "lead@project.com",
            TeamManagement.TeamRole.Owner
        );
        
        // Add team member
        teamManagement.addTeamMember(
            project,
            address(0x123),
            "Team Member",
            "member@project.com",
            TeamManagement.TeamRole.Member
        );
        
        // Create delegation
        uint256 validUntil = block.timestamp + 30 days;
        teamManagement.createDelegation(address(0x123), validUntil);
        
        // Query team
        TeamMember[] memory team = teamManagement.getProjectTeamMembers(project);
        
        // Check delegation
        bool isActive = teamManagement.isDelegationActive(msg.sender);
        address delegatee = teamManagement.getDelegatee(msg.sender);
    }
}
```

## Events

Monitor team activities through these events:

```solidity
event TeamMemberAdded(
    address indexed project,
    address indexed member,
    TeamRole role
);

event DelegationCreated(
    address indexed delegator,
    address indexed delegatee,
    uint256 validUntil
);

event DelegationRevoked(
    address indexed delegator,
    address indexed delegatee
);
```

## Best Practices

1. **Team Structure**
   - Define clear roles
   - Maintain role hierarchy
   - Document responsibilities
   - Update roles as needed

2. **Member Management**
   - Verify member identities
   - Keep information current
   - Monitor active status
   - Regular team audits

3. **Delegation System**
   - Set appropriate durations
   - Monitor active delegations
   - Regular delegation reviews
   - Clear delegation paths

4. **Access Control**
   - Implement role checks
   - Validate permissions
   - Monitor role changes
   - Audit access patterns

## Testing Example

Here's how to test the team management system:

```solidity
contract TeamManagementTest is Test {
    TeamManagement public teamMgmt;
    address project = address(0x1);
    address member = address(0x2);
    address delegatee = address(0x3);
    
    function setUp() public {
        teamMgmt = new TeamManagement();
    }
    
    function testTeamManagement() public {
        // Add team member
        teamMgmt.addTeamMember(
            project,
            member,
            "Test Member",
            "test@example.com",
            TeamManagement.TeamRole.Member
        );
        
        // Create delegation
        vm.startPrank(member);
        uint256 validUntil = block.timestamp + 1 days;
        teamMgmt.createDelegation(delegatee, validUntil);
        
        // Verify delegation
        assertTrue(teamMgmt.isDelegationActive(member));
        assertEq(teamMgmt.getDelegatee(member), delegatee);
        
        // Revoke delegation
        teamMgmt.revokeDelegation();
        assertFalse(teamMgmt.isDelegationActive(member));
        
        vm.stopPrank();
    }
}
```

## Security Considerations

1. **Role Management**
   - Validate role assignments
   - Protect role changes
   - Maintain role hierarchy
   - Audit role access

2. **Delegation Security**
   - Verify delegation periods
   - Protect delegation changes
   - Monitor active delegations
   - Handle expired delegations

3. **Member Data**
   - Protect member information
   - Validate email formats
   - Secure member updates
   - Handle member removal

4. **Access Validation**
   - Check permissions
   - Validate operations
   - Monitor activities
   - Handle edge cases
