# DisputeResolution Contract Tutorial

The DisputeResolution contract provides a structured system for handling project-related disputes on the platform. It enables users to initiate disputes, mediators to review and resolve them, and maintains a transparent record of dispute history.

## Core Features

1. Dispute Management
2. Mediator System
3. Project-specific Tracking
4. Status Progression

## Dispute Categories

The system supports five types of disputes:

1. **Funding**
   - Payment-related issues
   - Fund distribution conflicts
   - Budget disagreements

2. **MilestoneCompletion**
   - Milestone achievement disputes
   - Completion criteria conflicts
   - Timeline disagreements

3. **Collaboration**
   - Team communication issues
   - Contribution disputes
   - Responsibility conflicts

4. **Deliverables**
   - Quality of deliverables
   - Scope disagreements
   - Technical specification conflicts

5. **Other**
   - General disputes
   - Miscellaneous issues

## Dispute Status Flow

Disputes progress through the following statuses:

1. **Initiated**
   - Initial dispute filing
   - Awaiting review

2. **UnderReview**
   - Being examined by mediators
   - Evidence collection phase

3. **Mediation**
   - Active mediation process
   - Parties working towards resolution

4. **Resolved**
   - Resolution reached
   - Solution implemented

5. **Closed**
   - Dispute formally closed
   - No further action needed

## Core Functions

### Initiating a Dispute

Users can create new disputes:

```solidity
function initiateDispute(
    address project,
    address respondent,
    DisputeCategory category,
    string memory description
) public returns (uint256)
```

Example usage:
```solidity
uint256 disputeId = disputeResolution.initiateDispute(
    projectAddress,
    respondentAddress,
    DisputeResolution.DisputeCategory.Funding,
    "Delayed milestone payment for Phase 1"
);
```

### Managing Dispute Status

Approved mediators can update dispute status:

```solidity
function updateDisputeStatus(
    uint256 disputeId,
    DisputeStatus newStatus
) public onlyApprovedMediator
```

Example usage:
```solidity
// Move dispute to mediation
disputeResolution.updateDisputeStatus(
    disputeId,
    DisputeResolution.DisputeStatus.Mediation
);
```

### Resolving Disputes

Mediators can mark disputes as resolved:

```solidity
function resolveDispute(
    uint256 disputeId,
    string memory resolution
) public onlyApprovedMediator
```

Example usage:
```solidity
disputeResolution.resolveDispute(
    disputeId,
    "Parties agreed to revised milestone schedule with adjusted payments"
);
```

## Mediator Management

### Adding Mediators

```solidity
function addMediator(address mediator) public
```

Example usage:
```solidity
disputeResolution.addMediator(mediatorAddress);
```

## Querying Disputes

### Get Project Disputes

Retrieve all disputes for a specific project:

```solidity
function getProjectDisputes(
    address project
) public view returns (uint256[] memory)
```

Example usage:
```solidity
uint256[] memory disputes = disputeResolution.getProjectDisputes(projectAddress);
```

## Integration Example

Here's a complete example of integrating the dispute resolution system:

```solidity
contract ProjectManagement {
    DisputeResolution public disputeResolution;
    
    function handleProjectDispute(
        address project,
        address respondent,
        string memory description
    ) external {
        // Initiate funding dispute
        uint256 disputeId = disputeResolution.initiateDispute(
            project,
            respondent,
            DisputeResolution.DisputeCategory.Funding,
            description
        );
        
        // Get project's active disputes
        uint256[] memory projectDisputes = disputeResolution.getProjectDisputes(project);
        
        // Get dispute details
        (
            uint256 id,
            address projectAddr,
            address initiator,
            address disputeRespondent,
            DisputeResolution.DisputeCategory category,
            string memory desc,
            DisputeResolution.DisputeStatus status,
            uint256 createdAt,
            uint256 resolvedAt,
            address mediator,
            string memory resolution
        ) = disputeResolution.disputes(disputeId);
    }
}
```

## Events

Monitor dispute activities through these events:

```solidity
event DisputeInitiated(
    uint256 indexed disputeId,
    address indexed project,
    address initiator,
    DisputeCategory category
);

event DisputeStatusChanged(
    uint256 indexed disputeId,
    DisputeStatus newStatus
);

event DisputeResolved(
    uint256 indexed disputeId,
    string resolution
);
```

## Best Practices

1. **Dispute Initiation**
   - Provide detailed descriptions
   - Include relevant evidence
   - Choose appropriate category
   - Monitor DisputeInitiated events

2. **Mediation Process**
   - Follow status progression
   - Document all communications
   - Maintain impartiality
   - Track DisputeStatusChanged events

3. **Resolution Handling**
   - Document resolution clearly
   - Ensure all parties agree
   - Monitor DisputeResolved events
   - Verify implementation

4. **Project Management**
   - Track active disputes
   - Monitor resolution timelines
   - Maintain dispute history
   - Review common dispute patterns

## Testing Example

Here's how to test the dispute resolution system:

```solidity
contract DisputeResolutionTest is Test {
    DisputeResolution public disputes;
    address project = address(0x1);
    address initiator = address(0x2);
    address respondent = address(0x3);
    address mediator = address(0x4);
    
    function setUp() public {
        disputes = new DisputeResolution();
        disputes.addMediator(mediator);
    }
    
    function testDisputeFlow() public {
        // Initiate dispute
        vm.prank(initiator);
        uint256 disputeId = disputes.initiateDispute(
            project,
            respondent,
            DisputeResolution.DisputeCategory.Funding,
            "Payment dispute"
        );
        
        // Update status
        vm.prank(mediator);
        disputes.updateDisputeStatus(
            disputeId,
            DisputeResolution.DisputeStatus.Mediation
        );
        
        // Resolve dispute
        vm.prank(mediator);
        disputes.resolveDispute(
            disputeId,
            "Payment schedule adjusted"
        );
        
        // Verify resolution
        (,,,,,,DisputeResolution.DisputeStatus status,,,, string memory resolution) = 
            disputes.disputes(disputeId);
            
        assertEq(uint256(status), uint256(DisputeResolution.DisputeStatus.Resolved));
        assertEq(resolution, "Payment schedule adjusted");
    }
}
```

## Security Considerations

1. **Access Control**
   - Only approved mediators can update status
   - Only approved mediators can resolve disputes
   - Proper mediator management

2. **Data Integrity**
   - Immutable dispute history
   - Transparent status tracking
   - Clear resolution documentation

3. **Process Management**
   - Logical status progression
   - Proper event emission
   - Accurate timestamp recording

4. **Project Tracking**
   - Accurate dispute mapping
   - Project-specific history
   - Active dispute monitoring
