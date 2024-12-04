# ProjectPortfolio Contract Tutorial

The ProjectPortfolio contract enables users to create and manage professional portfolios showcasing their project work. It provides features for organizing projects, highlighting achievements, and controlling portfolio visibility.

## Core Features

1. Portfolio Management
2. Project Showcasing
3. Privacy Controls
4. Featured Items System

## Portfolio Structure

### Portfolio Items

Each portfolio item contains:
- Project ID
- Title
- Description
- Tags
- Media URL
- Featured status
- Timestamp

### Portfolio Metadata

Portfolio-level information includes:
- Title
- Description
- Highlighted Skills
- Privacy Setting

## Core Functions

### Adding Portfolio Items

Add projects to your portfolio:

```solidity
function addPortfolioItem(
    uint256 projectId,
    string calldata description,
    string[] calldata tags,
    string calldata mediaUrl,
    bool featured
) external
```

Example usage:
```solidity
string[] memory tags = new string[](2);
tags[0] = "DeFi";
tags[1] = "Smart Contracts";

portfolio.addPortfolioItem(
    projectId,
    "Led development of decentralized exchange",
    tags,
    "ipfs://Qm...",
    true  // featured
);
```

### Updating Portfolio Metadata

Customize your portfolio presentation:

```solidity
function updatePortfolioMetadata(
    string calldata title,
    string calldata description,
    string[] calldata highlightedSkills,
    bool isPublic
) external
```

Example usage:
```solidity
string[] memory skills = new string[](3);
skills[0] = "Solidity";
skills[1] = "Smart Contract Security";
skills[2] = "DeFi Protocol Design";

portfolio.updatePortfolioMetadata(
    "Blockchain Developer Portfolio",
    "Specialized in DeFi and Security",
    skills,
    true  // public visibility
);
```

### Managing Portfolio Items

Update or remove portfolio items:

```solidity
// Update an item
function updatePortfolioItem(
    uint256 projectId,
    string calldata description,
    string[] calldata tags,
    string calldata mediaUrl,
    bool featured
) external

// Remove an item
function removePortfolioItem(uint256 projectId) external
```

Example usage:
```solidity
// Update item
string[] memory newTags = new string[](1);
newTags[0] = "Updated Project";

portfolio.updatePortfolioItem(
    projectId,
    "Updated description",
    newTags,
    "ipfs://new-media",
    true
);

// Remove item
portfolio.removePortfolioItem(projectId);
```

## Querying Portfolios

### Get All Portfolio Items

Retrieve all items in a portfolio:

```solidity
function getPortfolioItems(address user)
    external
    view
    returns (PortfolioItem[] memory)
```

### Get Featured Items

Retrieve only featured portfolio items:

```solidity
function getFeaturedItems(address user)
    external
    view
    returns (PortfolioItem[] memory)
```

### Get Portfolio Metadata

Retrieve portfolio-level information:

```solidity
function getPortfolioMetadata(address user)
    external
    view
    returns (
        string memory title,
        string memory description,
        string[] memory highlightedSkills,
        bool isPublic
    )
```

## Integration Example

Here's a complete example of portfolio management:

```solidity
contract PortfolioManager {
    ProjectPortfolio public portfolio;
    
    function setupPortfolio() external {
        // Update portfolio metadata
        string[] memory skills = new string[](2);
        skills[0] = "Smart Contracts";
        skills[1] = "DeFi";
        
        portfolio.updatePortfolioMetadata(
            "DeFi Developer Portfolio",
            "Specialized in DeFi protocols",
            skills,
            true  // public
        );
        
        // Add portfolio item
        string[] memory tags = new string[](1);
        tags[0] = "DeFi";
        
        portfolio.addPortfolioItem(
            1,  // projectId
            "Automated Market Maker Protocol",
            tags,
            "ipfs://Qm...",
            true  // featured
        );
        
        // Get portfolio data
        PortfolioItem[] memory items = portfolio.getPortfolioItems(address(this));
        PortfolioItem[] memory featured = portfolio.getFeaturedItems(address(this));
    }
}
```

## Events

Monitor portfolio activities through these events:

```solidity
event PortfolioItemAdded(address indexed user, uint256 indexed projectId);
event PortfolioItemRemoved(address indexed user, uint256 indexed projectId);
event PortfolioMetadataUpdated(address indexed user);
event PortfolioItemUpdated(address indexed user, uint256 indexed projectId);
```

## Best Practices

1. **Portfolio Setup**
   - Create clear, professional descriptions
   - Use relevant tags
   - Include quality media content
   - Highlight key achievements

2. **Content Management**
   - Keep descriptions concise
   - Update regularly
   - Maintain relevant tags
   - Curate featured items

3. **Privacy Management**
   - Consider visibility settings
   - Review public content
   - Update privacy as needed
   - Protect sensitive information

4. **Media Management**
   - Use stable media links
   - Optimize media content
   - Backup media files
   - Update broken links

## Testing Example

Here's how to test the portfolio system:

```solidity
contract ProjectPortfolioTest is Test {
    ProjectPortfolio public portfolio;
    address user = address(0x1);
    
    function setUp() public {
        portfolio = new ProjectPortfolio(
            payable(address(0x2)),  // project contract
            address(0x3)            // user profile contract
        );
    }
    
    function testPortfolioManagement() public {
        vm.startPrank(user);
        
        // Set up portfolio metadata
        string[] memory skills = new string[](1);
        skills[0] = "Solidity";
        
        portfolio.updatePortfolioMetadata(
            "Test Portfolio",
            "Test Description",
            skills,
            true
        );
        
        // Add portfolio item
        string[] memory tags = new string[](1);
        tags[0] = "Test";
        
        portfolio.addPortfolioItem(
            1,  // projectId
            "Test Project",
            tags,
            "test://media",
            true
        );
        
        // Verify portfolio
        PortfolioItem[] memory items = portfolio.getPortfolioItems(user);
        assertEq(items.length, 1);
        assertEq(items[0].projectId, 1);
        
        vm.stopPrank();
    }
}
```

## Security Considerations

1. **Access Control**
   - Verify user registration
   - Enforce privacy settings
   - Protect portfolio updates
   - Validate ownership

2. **Data Validation**
   - Verify project existence
   - Validate media URLs
   - Check tag validity
   - Ensure unique entries

3. **Privacy Protection**
   - Respect visibility settings
   - Protect private data
   - Validate viewers
   - Handle permissions

4. **Error Handling**
   - Handle missing items
   - Manage duplicates
   - Process removals safely
   - Validate updates
