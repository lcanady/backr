# Badge Contract Tutorial

The Badge contract implements an NFT-based achievement system that rewards users for their platform participation with badges that provide tangible benefits and governance weight multipliers.

## Core Features

1. Achievement Badges (NFTs)
2. Tiered Progression System
3. Platform Benefits
4. Governance Weight Multipliers

## Badge Types and Tiers

### Badge Types

1. **Early Supporter**
   - Awarded to first 100 users to back a project
   - 5% platform discount
   - 10x governance weight

2. **Power Backer**
   - For users who back multiple projects
   - 10% platform discount
   - 5x governance weight
   - Progression based on number of backed projects

3. **Liquidity Provider**
   - For significant liquidity contributors
   - 15% platform discount
   - 7.5x governance weight

4. **Governance Active**
   - For active governance participants
   - 7.5% platform discount
   - 20x governance weight
   - Progression based on governance participation

### Badge Tiers

Each badge can progress through four tiers:
1. **Bronze** (Starting tier)
2. **Silver** (25% governance bonus)
3. **Gold** (50% governance bonus)
4. **Platinum** (100% governance bonus)

## Badge Management

### Awarding Badges

Platform administrators can award badges to users:

```solidity
// Award a badge to a user
function awardBadge(
    address recipient,
    BadgeType badgeType,
    string memory uri
) external onlyOwner
```

Example usage:
```solidity
// Award Early Supporter badge
badge.awardBadge(
    userAddress,
    Badge.BadgeType.EARLY_SUPPORTER,
    "ipfs://Qm..." // Metadata URI
);
```

### Recording Actions

Track user actions for badge progression:

```solidity
// Record a qualifying action
function recordAction(
    address user,
    BadgeType badgeType
) external onlyOwner
```

Example usage:
```solidity
// Record a project backing for Power Backer progression
badge.recordAction(
    userAddress,
    Badge.BadgeType.POWER_BACKER
);
```

### Revoking Badges

Administrators can revoke badges if necessary:

```solidity
function revokeBadge(uint256 tokenId) external onlyOwner
```

## Tier Requirements

### Power Backer Requirements
- Bronze: 5 backed projects
- Silver: 10 backed projects
- Gold: 20 backed projects
- Platinum: 50 backed projects

### Governance Active Requirements
- Bronze: 3 governance participations
- Silver: 10 governance participations
- Gold: 25 governance participations
- Platinum: 100 governance participations

## Benefits System

### Platform Discounts

Users can accumulate benefits from multiple badges:

```solidity
// Get total benefits for a user
function getTotalBenefits(address user) external view returns (uint256)
```

**Important Notes**:
- Benefits are in basis points (100 = 1%)
- Maximum total benefit capped at 25%
- Benefits stack from different badge types

### Governance Weights

Badges provide governance weight multipliers:

```solidity
// Get total governance weight for a user
function getGovernanceWeight(address user) external view returns (uint256)
```

**Weight Calculation**:
- Base weight: 1x (100 basis points)
- Tier bonuses apply to badge weights:
  - Silver: +25% bonus
  - Gold: +50% bonus
  - Platinum: +100% bonus

## Integration Example

Here's a complete example of integrating the badge system:

```solidity
contract PlatformCore {
    Badge public badge;
    
    function backProject(uint256 projectId) external {
        // Apply badge benefits to transaction
        uint256 discount = badge.getTotalBenefits(msg.sender);
        uint256 cost = calculateCostWithDiscount(basePrice, discount);
        
        // Process backing...
        
        // Record action for Power Backer badge
        badge.recordAction(msg.sender, Badge.BadgeType.POWER_BACKER);
    }
    
    function vote(uint256 proposalId) external {
        // Apply governance weight
        uint256 weight = badge.getGovernanceWeight(msg.sender);
        uint256 votingPower = calculateVotingPower(baseVotes, weight);
        
        // Process vote...
        
        // Record action for Governance Active badge
        badge.recordAction(msg.sender, Badge.BadgeType.GOVERNANCE_ACTIVE);
    }
}
```

## Events

Monitor badge activities through these events:

```solidity
event BadgeAwarded(address indexed recipient, BadgeType badgeType, BadgeTier tier, uint256 tokenId);
event BadgeRevoked(address indexed holder, uint256 tokenId);
event BadgeProgressed(address indexed holder, uint256 tokenId, BadgeTier newTier);
event BenefitUpdated(BadgeType badgeType, uint256 newBenefit);
event GovernanceWeightUpdated(BadgeType indexed badgeType, uint256 newWeight);
```

## Best Practices

1. **Badge Awarding**
   - Verify eligibility before awarding badges
   - Use meaningful metadata URIs
   - Monitor BadgeAwarded events

2. **Action Recording**
   - Record actions immediately after qualifying events
   - Verify action authenticity
   - Monitor BadgeProgressed events

3. **Benefits Management**
   - Keep benefits reasonable (under 25% total)
   - Consider economic impact of discounts
   - Monitor BenefitUpdated events

4. **Governance Integration**
   - Apply weights correctly in voting systems
   - Consider cumulative effect of tier bonuses
   - Monitor GovernanceWeightUpdated events

## Testing Example

Here's how to test the badge system:

```solidity
contract BadgeTest is Test {
    Badge public badge;
    address user = address(0x1);
    
    function setUp() public {
        badge = new Badge();
    }
    
    function testBadgeProgression() public {
        // Award Power Backer badge
        badge.awardBadge(
            user,
            Badge.BadgeType.POWER_BACKER,
            "ipfs://test"
        );
        
        // Record actions to reach Silver
        for(uint i = 0; i < 10; i++) {
            badge.recordAction(user, Badge.BadgeType.POWER_BACKER);
        }
        
        // Get badge token ID
        uint256 tokenId = badge.getUserBadgeTokenId(user, Badge.BadgeType.POWER_BACKER);
        
        // Verify tier progression
        assertEq(uint256(badge.badgeTiers(tokenId)), uint256(Badge.BadgeTier.SILVER));
    }
}
```

## Security Considerations

1. **Access Control**
   - Only owner can award/revoke badges
   - Only owner can record actions
   - Only owner can update benefits/weights

2. **Benefit Limits**
   - Total benefits capped at 25%
   - Individual benefits capped at 100%
   - Governance weights reasonably scaled

3. **NFT Security**
   - Implements ERC721 standard
   - Uses OpenZeppelin's secure implementations
   - Proper token URI management

4. **Progression System**
   - Automatic tier progression
   - Non-reversible progression
   - Clear tier requirements
