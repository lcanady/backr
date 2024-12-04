# ProposalTemplates Contract Tutorial

The ProposalTemplates contract provides a system for creating and managing standardized governance proposal templates, making it easier for users to create well-structured proposals while ensuring consistency and security.

## Core Features

1. Template Management System
2. Role-based Access Control
3. Dynamic Parameter Handling
4. Proposal Call Encoding

## Template Structure

### Template Components
- Name
- Description
- Target Contract Address
- Function Selector
- Parameter Names
- Parameter Types
- Active Status

### Access Control
- DEFAULT_ADMIN_ROLE: Contract administration
- TEMPLATE_ADMIN_ROLE: Template management

## Template Management

### Creating Templates

Administrators can create new proposal templates:

```solidity
function createTemplate(
    string memory name,
    string memory description,
    address targetContract,
    bytes4 functionSelector,
    string[] memory parameterNames,
    string[] memory parameterTypes
) external onlyRole(TEMPLATE_ADMIN_ROLE)
```

Example usage:
```solidity
// Create a template for updating platform fees
string[] memory paramNames = new string[](1);
paramNames[0] = "newFeePercentage";

string[] memory paramTypes = new string[](1);
paramTypes[0] = "uint256";

proposalTemplates.createTemplate(
    "Update Platform Fee",
    "Proposal to update the platform fee percentage",
    platformAddress,
    bytes4(keccak256("setFeePercentage(uint256)")),
    paramNames,
    paramTypes
);
```

### Deactivating Templates

Administrators can deactivate obsolete templates:

```solidity
function deactivateTemplate(uint256 templateId) external onlyRole(TEMPLATE_ADMIN_ROLE)
```

Example usage:
```solidity
// Deactivate an obsolete template
proposalTemplates.deactivateTemplate(templateId);
```

### Retrieving Template Information

View template details:

```solidity
function getTemplate(uint256 templateId) external view returns (
    string memory name,
    string memory description,
    address targetContract,
    bytes4 functionSelector,
    string[] memory parameterNames,
    string[] memory parameterTypes,
    bool active
)
```

Example usage:
```solidity
// Get template details
(
    string memory name,
    string memory description,
    address target,
    bytes4 selector,
    string[] memory paramNames,
    string[] memory paramTypes,
    bool active
) = proposalTemplates.getTemplate(templateId);
```

## Proposal Generation

### Generating Descriptions

Create human-readable proposal descriptions:

```solidity
function generateDescription(
    uint256 templateId,
    string[] memory parameters
) public view returns (string memory)
```

Example usage:
```solidity
// Generate proposal description
string[] memory params = new string[](1);
params[0] = "2.5";

string memory description = proposalTemplates.generateDescription(
    templateId,
    params
);
```

### Encoding Proposal Calls

Generate encoded function calls for proposals:

```solidity
function encodeProposalCall(
    uint256 templateId,
    bytes memory parameters
) public view returns (address, bytes memory)
```

Example usage:
```solidity
// Encode proposal call
bytes memory params = abi.encode(250); // 2.5% encoded as basis points
(address target, bytes memory data) = proposalTemplates.encodeProposalCall(
    templateId,
    params
);
```

## Integration Example

Here's a complete example of integrating proposal templates with a governance system:

```solidity
contract GovernanceSystem {
    ProposalTemplates public templates;
    
    function createProposal(
        uint256 templateId,
        string[] memory humanReadableParams,
        bytes memory encodedParams
    ) external {
        // Generate proposal description
        string memory description = templates.generateDescription(
            templateId,
            humanReadableParams
        );
        
        // Get encoded call data
        (address target, bytes memory data) = templates.encodeProposalCall(
            templateId,
            encodedParams
        );
        
        // Create proposal
        uint256 proposalId = _createProposal(
            description,
            target,
            data
        );
        
        emit ProposalCreated(proposalId, msg.sender, templateId);
    }
    
    function _createProposal(
        string memory description,
        address target,
        bytes memory data
    ) internal returns (uint256) {
        // Implementation specific to governance system
        // ...
    }
}
```

## Events

Monitor template management activities:

```solidity
event TemplateCreated(uint256 indexed templateId, string name);
event TemplateUpdated(uint256 indexed templateId);
event TemplateDeactivated(uint256 indexed templateId);
```

## Best Practices

1. **Template Creation**
   - Use clear, descriptive names
   - Provide detailed descriptions
   - Verify parameter counts match
   - Document parameter types clearly

2. **Parameter Management**
   - Use consistent parameter naming
   - Validate parameter types
   - Consider parameter constraints
   - Document expected formats

3. **Template Maintenance**
   - Regular template reviews
   - Deactivate obsolete templates
   - Update documentation
   - Monitor usage patterns

4. **Integration**
   - Validate encoded calls
   - Handle template updates
   - Monitor events
   - Implement proper error handling

## Testing Example

Here's how to test the proposal templates system:

```solidity
contract ProposalTemplatesTest is Test {
    ProposalTemplates public templates;
    address admin = address(0x1);
    
    function setUp() public {
        templates = new ProposalTemplates();
        vm.startPrank(admin);
        
        // Setup template admin role
        templates.grantRole(templates.TEMPLATE_ADMIN_ROLE(), admin);
    }
    
    function testCreateTemplate() public {
        string[] memory paramNames = new string[](1);
        paramNames[0] = "newFee";
        
        string[] memory paramTypes = new string[](1);
        paramTypes[0] = "uint256";
        
        templates.createTemplate(
            "Update Fee",
            "Update platform fee",
            address(0x2),
            bytes4(keccak256("setFee(uint256)")),
            paramNames,
            paramTypes
        );
        
        // Verify template
        (
            string memory name,
            ,
            address target,
            bytes4 selector,
            string[] memory names,
            string[] memory types,
            bool active
        ) = templates.getTemplate(0);
        
        assertEq(name, "Update Fee");
        assertEq(target, address(0x2));
        assertEq(selector, bytes4(keccak256("setFee(uint256)")));
        assertEq(names[0], "newFee");
        assertEq(types[0], "uint256");
        assertTrue(active);
    }
    
    function testGenerateDescription() public {
        // Create template first
        // ... (setup as above)
        
        string[] memory params = new string[](1);
        params[0] = "100";
        
        string memory description = templates.generateDescription(0, params);
        assertTrue(bytes(description).length > 0);
    }
}
```

## Security Considerations

1. **Access Control**
   - Role-based permissions
   - Admin role management
   - Template activation control

2. **Input Validation**
   - Parameter count validation
   - Parameter type checking
   - Target contract verification

3. **Template Security**
   - Function selector validation
   - Target contract verification
   - Parameter encoding safety

4. **Integration Security**
   - Proper error handling
   - Event monitoring
   - State consistency checks
