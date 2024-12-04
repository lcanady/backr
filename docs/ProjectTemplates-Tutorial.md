# ProjectTemplates Contract Tutorial

The ProjectTemplates contract provides a system for creating and managing project templates, enabling standardized project initialization and consistent project structures across the platform.

## Core Features

1. Template Management
2. Project Type Classification
3. Required Fields Definition
4. Category Integration

## Template Types

The system supports six template types:

1. **TechInnovation**
   - Software Development
   - Hardware Projects
   - Technical Solutions

2. **SocialImpact**
   - Community Projects
   - Social Enterprises
   - Humanitarian Initiatives

3. **CreativeArts**
   - Digital Art
   - Music
   - Media Projects

4. **ResearchAndDevelopment**
   - Scientific Research
   - Product Development
   - Innovation Studies

5. **CommunityInitiative**
   - Local Projects
   - Community Programs
   - Grassroots Movements

6. **Other**
   - Custom Projects
   - Cross-domain Initiatives
   - Unique Ventures

## Template Structure

Each template contains:
- Unique ID
- Name
- Template Type
- Description
- Required Fields
- Recommended Categories
- Active Status
- Creator Address

## Core Functions

### Creating Templates

Create new project templates:

```solidity
function createTemplate(
    string memory name,
    TemplateType templateType,
    string memory description,
    string[] memory requiredFields,
    uint256[] memory recommendedCategories
) public returns (uint256)
```

Example usage:
```solidity
string[] memory fields = new string[](3);
fields[0] = "projectGoals";
fields[1] = "technicalSpecs";
fields[2] = "timeline";

uint256[] memory categories = new uint256[](2);
categories[0] = 1; // e.g., "DeFi" category
categories[1] = 2; // e.g., "Smart Contracts" category

uint256 templateId = projectTemplates.createTemplate(
    "DeFi Protocol Template",
    ProjectTemplates.TemplateType.TechInnovation,
    "Template for creating new DeFi protocols",
    fields,
    categories
);
```

### Using Templates

Use existing templates for new projects:

```solidity
function useTemplate(uint256 templateId)
    public
    view
    returns (Template memory)
```

Example usage:
```solidity
Template memory template = projectTemplates.useTemplate(templateId);

// Access template details
string memory name = template.name;
string[] memory requiredFields = template.requiredFields;
uint256[] memory categories = template.recommendedCategories;
```

### Querying Templates

Find templates by type:

```solidity
function getTemplatesByType(TemplateType templateType)
    public
    view
    returns (uint256[] memory)
```

Example usage:
```solidity
uint256[] memory techTemplates = projectTemplates.getTemplatesByType(
    ProjectTemplates.TemplateType.TechInnovation
);
```

## Integration Example

Here's a complete example of template management:

```solidity
contract ProjectManager {
    ProjectTemplates public templates;
    
    function setupTemplates() external {
        // Create required fields
        string[] memory fields = new string[](4);
        fields[0] = "title";
        fields[1] = "description";
        fields[2] = "timeline";
        fields[3] = "budget";
        
        // Set recommended categories
        uint256[] memory categories = new uint256[](2);
        categories[0] = 1; // Tech category
        categories[1] = 2; // Innovation category
        
        // Create template
        uint256 templateId = templates.createTemplate(
            "Standard Tech Project",
            ProjectTemplates.TemplateType.TechInnovation,
            "Template for technology projects",
            fields,
            categories
        );
        
        // Use template
        Template memory template = templates.useTemplate(templateId);
        
        // Get all tech templates
        uint256[] memory techTemplates = templates.getTemplatesByType(
            ProjectTemplates.TemplateType.TechInnovation
        );
    }
}
```

## Events

Monitor template activities through these events:

```solidity
event TemplateCreated(
    uint256 indexed templateId,
    string name,
    TemplateType templateType
);

event TemplateUsed(
    address indexed project,
    uint256 templateId
);
```

## Best Practices

1. **Template Creation**
   - Use clear, descriptive names
   - Include essential required fields
   - Choose appropriate categories
   - Provide detailed descriptions

2. **Required Fields**
   - Include all necessary information
   - Use consistent field names
   - Consider project type needs
   - Balance completeness with usability

3. **Category Integration**
   - Validate category existence
   - Choose relevant categories
   - Consider cross-category needs
   - Update as categories change

4. **Template Management**
   - Monitor template usage
   - Update outdated templates
   - Remove unused templates
   - Maintain template quality

## Testing Example

Here's how to test the template system:

```solidity
contract ProjectTemplatesTest is Test {
    ProjectTemplates public templates;
    ProjectCategories public categories;
    
    function setUp() public {
        categories = new ProjectCategories();
        templates = new ProjectTemplates(address(categories));
    }
    
    function testTemplateCreation() public {
        // Create required fields
        string[] memory fields = new string[](2);
        fields[0] = "name";
        fields[1] = "description";
        
        // Create categories
        uint256[] memory cats = new uint256[](1);
        cats[0] = 1;
        
        // Create template
        uint256 templateId = templates.createTemplate(
            "Test Template",
            ProjectTemplates.TemplateType.TechInnovation,
            "Test Description",
            fields,
            cats
        );
        
        // Use template
        Template memory template = templates.useTemplate(templateId);
        
        // Verify template
        assertEq(template.name, "Test Template");
        assertEq(template.requiredFields.length, 2);
        assertEq(template.recommendedCategories.length, 1);
    }
}
```

## Security Considerations

1. **Data Validation**
   - Validate category existence
   - Check required fields
   - Verify template activity
   - Validate input lengths

2. **Access Control**
   - Consider creator permissions
   - Manage template updates
   - Control template usage
   - Monitor template creation

3. **Template Integrity**
   - Maintain consistent structure
   - Validate field requirements
   - Ensure category validity
   - Check template status

4. **System Scalability**
   - Manage template growth
   - Optimize queries
   - Handle template updates
   - Consider gas costs
