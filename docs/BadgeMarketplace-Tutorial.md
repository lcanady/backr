# BadgeMarketplace Contract Tutorial

The BadgeMarketplace contract enables users to trade their achievement badges and supports time-limited badge features. It provides a secure way to list, purchase, and manage badge transfers on the platform.

## Core Features

1. Badge Listing Management
2. Secure Purchase System
3. Time-Limited Badge Support
4. Active Listings Query

## Marketplace Operations

### Listing a Badge

To list a badge for sale, users must own the badge and approve the marketplace:

```solidity
// First approve the marketplace
badge.approve(marketplaceAddress, tokenId);

// Then list the badge
marketplace.listBadge(
    tokenId,    // Badge token ID
    price,      // Price in wei
    expiry      // 0 for permanent, timestamp for time-limited
);
```

**Important Notes**:
- Only badge owners can list
- Marketplace must be approved for transfer
- Expiry of 0 means permanent badge
- Price is in wei (1 ether = 1e18 wei)

### Purchasing a Badge

Users can purchase listed badges by sending the required payment:

```solidity
// Purchase a badge
marketplace.purchaseBadge{value: price}(tokenId);
```

**Purchase Process**:
1. Validates listing exists and payment sufficient
2. Checks badge hasn't expired (for time-limited badges)
3. Transfers badge ownership
4. Sends payment to seller
5. Refunds excess payment if any

### Unlisting a Badge

Sellers can remove their badges from the marketplace:

```solidity
marketplace.unlistBadge(tokenId);
```

## Time-Limited Badges

The marketplace supports time-limited badges that expire after a certain timestamp:

```solidity
// Check if a badge has expired
bool expired = marketplace.isBadgeExpired(tokenId);
```

**Time-Limited Features**:
- Set expiry when listing
- Cannot purchase expired badges
- Expiry status publicly queryable
- Permanent badges use expiry = 0

## Viewing Listings

Get all active (non-expired) listings:

```solidity
(
    uint256[] memory tokenIds,
    uint256[] memory prices,
    address[] memory sellers,
    uint256[] memory expiries
) = marketplace.getActiveListings();
```

## Integration Example

Here's a complete example of integrating the marketplace:

```solidity
contract MarketplaceUI {
    BadgeMarketplace public marketplace;
    Badge public badge;
    
    function listMyBadge(
        uint256 tokenId,
        uint256 price,
        uint256 expiry
    ) external {
        // First approve marketplace
        badge.approve(address(marketplace), tokenId);
        
        // Then list badge
        marketplace.listBadge(tokenId, price, expiry);
    }
    
    function buyBadge(uint256 tokenId) external payable {
        // Get listing details
        (address seller, uint256 price, uint256 expiry) = marketplace.listings(tokenId);
        
        // Verify badge isn't expired
        require(!marketplace.isBadgeExpired(tokenId), "Badge expired");
        
        // Purchase badge
        marketplace.purchaseBadge{value: price}(tokenId);
    }
    
    function displayActiveListings() external view returns (
        uint256[] memory tokens,
        uint256[] memory prices,
        address[] memory sellers,
        uint256[] memory expiries
    ) {
        return marketplace.getActiveListings();
    }
}
```

## Events

Monitor marketplace activity through these events:

```solidity
event BadgeListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 expiry);
event BadgeSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
event BadgeUnlisted(uint256 indexed tokenId);
event BadgeExpired(uint256 indexed tokenId);
```

## Best Practices

1. **Listing Management**
   - Verify badge ownership before listing
   - Set reasonable prices
   - Consider time-limited use cases
   - Monitor BadgeListed events

2. **Purchase Handling**
   - Check badge validity before purchase
   - Verify price and expiry
   - Handle failed transactions
   - Monitor BadgeSold events

3. **Time-Limited Badges**
   - Set appropriate expiry times
   - Check expiry before interactions
   - Monitor BadgeExpired events
   - Consider timezone implications

4. **Market Monitoring**
   - Track active listings
   - Monitor price trends
   - Watch for unusual activity
   - Use events for updates

## Testing Example

Here's how to test the marketplace functionality:

```solidity
contract MarketplaceTest is Test {
    BadgeMarketplace public marketplace;
    Badge public badge;
    address seller = address(0x1);
    address buyer = address(0x2);
    
    function setUp() public {
        badge = new Badge();
        marketplace = new BadgeMarketplace(address(badge));
        
        // Mint a badge to seller
        badge.awardBadge(
            seller,
            Badge.BadgeType.POWER_BACKER,
            "ipfs://test"
        );
    }
    
    function testBadgeSale() public {
        vm.startPrank(seller);
        
        // Approve and list badge
        uint256 tokenId = 1;
        uint256 price = 1 ether;
        badge.approve(address(marketplace), tokenId);
        marketplace.listBadge(tokenId, price, 0);
        
        vm.stopPrank();
        
        // Purchase badge
        vm.startPrank(buyer);
        vm.deal(buyer, 1 ether);
        
        marketplace.purchaseBadge{value: price}(tokenId);
        
        // Verify ownership transferred
        assertEq(badge.ownerOf(tokenId), buyer);
    }
}
```

## Security Considerations

1. **Reentrancy Protection**
   - Uses OpenZeppelin's ReentrancyGuard
   - Clears listing before transfer
   - Handles payments last

2. **Access Control**
   - Only owners can list/unlist
   - Requires marketplace approval
   - Ownership verified on listing

3. **Payment Handling**
   - Secure payment transfers
   - Excess payment refunding
   - Failed transfer handling

4. **Time Management**
   - Secure expiry checking
   - Block timestamp usage
   - Expired badge protection
