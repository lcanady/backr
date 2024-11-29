// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Badge.sol";

/**
 * @title BadgeMarketplace
 * @dev Handles badge trading and time-limited badge features
 */
contract BadgeMarketplace is ReentrancyGuard, Ownable {
    Badge public immutable badgeContract;

    struct Listing {
        address seller;
        uint256 price;
        uint256 expiry; // 0 for permanent badges, timestamp for time-limited
    }

    // TokenId => Listing
    mapping(uint256 => Listing) public listings;

    // Time-limited badge expiry tracking
    mapping(uint256 => uint256) public badgeExpiry;

    event BadgeListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 expiry);
    event BadgeSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event BadgeUnlisted(uint256 indexed tokenId);
    event BadgeExpired(uint256 indexed tokenId);

    constructor(address _badgeContract) {
        badgeContract = Badge(_badgeContract);
    }

    /**
     * @dev List a badge for sale
     * @param tokenId The ID of the badge to list
     * @param price The price in wei
     * @param expiry The expiration timestamp (0 for permanent badges)
     */
    function listBadge(uint256 tokenId, uint256 price, uint256 expiry) external {
        require(badgeContract.ownerOf(tokenId) == msg.sender, "Not badge owner");
        require(badgeContract.getApproved(tokenId) == address(this), "Marketplace not approved");

        listings[tokenId] = Listing({seller: msg.sender, price: price, expiry: expiry});

        if (expiry > 0) {
            badgeExpiry[tokenId] = expiry;
        }

        emit BadgeListed(tokenId, msg.sender, price, expiry);
    }

    /**
     * @dev Purchase a listed badge
     * @param tokenId The ID of the badge to purchase
     */
    function purchaseBadge(uint256 tokenId) external payable nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "Badge not listed");
        require(msg.value >= listing.price, "Insufficient payment");

        if (listing.expiry > 0) {
            require(block.timestamp < listing.expiry, "Badge expired");
        }

        address seller = listing.seller;
        uint256 price = listing.price;

        // Clear the listing first to prevent reentrancy
        delete listings[tokenId];

        // Transfer badge ownership
        badgeContract.transferFrom(seller, msg.sender, tokenId);

        // Transfer payment to seller
        (bool success,) = seller.call{value: price}("");
        require(success, "Transfer to seller failed");

        // Refund excess payment
        uint256 excess = msg.value - price;
        if (excess > 0) {
            (bool refundSuccess,) = msg.sender.call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }

        emit BadgeSold(tokenId, seller, msg.sender, price);
    }

    /**
     * @dev Unlist a badge from the marketplace
     * @param tokenId The ID of the badge to unlist
     */
    function unlistBadge(uint256 tokenId) external {
        require(listings[tokenId].seller == msg.sender, "Not seller");
        delete listings[tokenId];
        emit BadgeUnlisted(tokenId);
    }

    /**
     * @dev Check if a badge has expired
     * @param tokenId The ID of the badge to check
     * @return bool True if the badge has expired
     */
    function isBadgeExpired(uint256 tokenId) public view returns (bool) {
        uint256 expiry = badgeExpiry[tokenId];
        return expiry > 0 && block.timestamp >= expiry;
    }

    /**
     * @dev Get all active listings
     * @return tokenIds Array of token IDs with active listings
     * @return prices Array of prices for the active listings
     * @return sellers Array of sellers for the active listings
     * @return expiries Array of expiry timestamps for the active listings
     */
    function getActiveListings()
        external
        view
        returns (
            uint256[] memory tokenIds,
            uint256[] memory prices,
            address[] memory sellers,
            uint256[] memory expiries
        )
    {
        uint256 count = 0;
        for (uint256 i = 1; i <= badgeContract.totalSupply(); i++) {
            if (listings[i].seller != address(0) && !isBadgeExpired(i)) {
                count++;
            }
        }

        tokenIds = new uint256[](count);
        prices = new uint256[](count);
        sellers = new address[](count);
        expiries = new uint256[](count);

        uint256 index = 0;
        for (uint256 i = 1; i <= badgeContract.totalSupply(); i++) {
            if (listings[i].seller != address(0) && !isBadgeExpired(i)) {
                tokenIds[index] = i;
                prices[index] = listings[i].price;
                sellers[index] = listings[i].seller;
                expiries[index] = listings[i].expiry;
                index++;
            }
        }
    }
}
