// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Badge
 * @dev NFT-based badge system for platform achievements
 */
contract Badge is ERC721URIStorage, Ownable {
    uint256 private _tokenIds;

    // Badge types and their requirements
    enum BadgeType {
        EARLY_SUPPORTER, // First 100 users to back a project
        POWER_BACKER, // Backed more than 5 projects
        LIQUIDITY_PROVIDER, // Provided significant liquidity
        GOVERNANCE_ACTIVE // Participated in multiple proposals

    }

    // Badge progression tiers
    enum BadgeTier {
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM
    }

    // Mapping from token ID to badge type
    mapping(uint256 => BadgeType) public badgeTypes;

    // Mapping from token ID to badge tier
    mapping(uint256 => BadgeTier) public badgeTiers;

    // Mapping from address to badge type to whether they have earned it
    mapping(address => mapping(BadgeType => bool)) public hasBadge;

    // Mapping from badge type to its benefits multiplier (in basis points, 100 = 1%)
    mapping(BadgeType => uint256) public badgeBenefits;

    // Mapping from badge type to tier requirements (e.g., number of actions needed)
    mapping(BadgeType => mapping(BadgeTier => uint256)) public tierRequirements;

    // Mapping from address to badge type to number of qualifying actions
    mapping(address => mapping(BadgeType => uint256)) public userActions;

    event BadgeAwarded(address indexed recipient, BadgeType badgeType, BadgeTier tier, uint256 tokenId);
    event BadgeRevoked(address indexed holder, uint256 tokenId);
    event BadgeProgressed(address indexed holder, uint256 tokenId, BadgeTier newTier);
    event BenefitUpdated(BadgeType badgeType, uint256 newBenefit);

    constructor() ERC721("Platform Achievement Badge", "BADGE") Ownable() {
        _tokenIds = 0;
        // Set initial badge benefits
        badgeBenefits[BadgeType.EARLY_SUPPORTER] = 500; // 5% discount
        badgeBenefits[BadgeType.POWER_BACKER] = 1000; // 10% discount
        badgeBenefits[BadgeType.LIQUIDITY_PROVIDER] = 1500; // 15% discount
        badgeBenefits[BadgeType.GOVERNANCE_ACTIVE] = 750; // 7.5% discount

        // Set tier requirements
        tierRequirements[BadgeType.POWER_BACKER][BadgeTier.BRONZE] = 5;
        tierRequirements[BadgeType.POWER_BACKER][BadgeTier.SILVER] = 10;
        tierRequirements[BadgeType.POWER_BACKER][BadgeTier.GOLD] = 20;
        tierRequirements[BadgeType.POWER_BACKER][BadgeTier.PLATINUM] = 50;

        tierRequirements[BadgeType.GOVERNANCE_ACTIVE][BadgeTier.BRONZE] = 3;
        tierRequirements[BadgeType.GOVERNANCE_ACTIVE][BadgeTier.SILVER] = 10;
        tierRequirements[BadgeType.GOVERNANCE_ACTIVE][BadgeTier.GOLD] = 25;
        tierRequirements[BadgeType.GOVERNANCE_ACTIVE][BadgeTier.PLATINUM] = 100;
    }

    /**
     * @dev Award a badge to an address with metadata
     * @param recipient Address to receive the badge
     * @param badgeType Type of badge to award
     * @param uri Metadata URI for the badge
     */
    function awardBadge(address recipient, BadgeType badgeType, string memory uri) external onlyOwner {
        require(!hasBadge[recipient][badgeType], "Badge already awarded");

        _tokenIds++;
        uint256 newTokenId = _tokenIds;

        _safeMint(recipient, newTokenId);
        _setTokenURI(newTokenId, uri);

        badgeTypes[newTokenId] = badgeType;
        badgeTiers[newTokenId] = BadgeTier.BRONZE;
        hasBadge[recipient][badgeType] = true;

        emit BadgeAwarded(recipient, badgeType, BadgeTier.BRONZE, newTokenId);
    }

    /**
     * @dev Revoke a badge from an address
     * @param tokenId ID of the badge to revoke
     */
    function revokeBadge(uint256 tokenId) external onlyOwner {
        address holder = ownerOf(tokenId);
        BadgeType badgeType = badgeTypes[tokenId];

        _burn(tokenId);
        hasBadge[holder][badgeType] = false;
        delete badgeTypes[tokenId];
        delete badgeTiers[tokenId];

        emit BadgeRevoked(holder, tokenId);
    }

    /**
     * @dev Record an action for a user that counts towards badge progression
     * @param user Address of the user
     * @param badgeType Type of badge to record action for
     */
    function recordAction(address user, BadgeType badgeType) external onlyOwner {
        userActions[user][badgeType]++;

        // Check if user has the badge and can progress to next tier
        if (hasBadge[user][badgeType]) {
            uint256 tokenId = getUserBadgeTokenId(user, badgeType);
            BadgeTier currentTier = badgeTiers[tokenId];

            if (currentTier != BadgeTier.PLATINUM) {
                BadgeTier nextTier = BadgeTier(uint256(currentTier) + 1);
                if (userActions[user][badgeType] >= tierRequirements[badgeType][nextTier]) {
                    badgeTiers[tokenId] = nextTier;
                    emit BadgeProgressed(user, tokenId, nextTier);
                }
            }
        }
    }

    /**
     * @dev Get the token ID of a user's badge for a specific type
     * @param user Address of the badge holder
     * @param badgeType Type of badge to look up
     * @return tokenId of the badge, or 0 if not found
     */
    function getUserBadgeTokenId(address user, BadgeType badgeType) public view returns (uint256) {
        for (uint256 i = 1; i <= _tokenIds; i++) {
            if (_exists(i) && ownerOf(i) == user && badgeTypes[i] == badgeType) {
                return i;
            }
        }
        return 0;
    }

    /**
     * @dev Update the benefit percentage for a badge type
     * @param badgeType Type of badge to update
     * @param newBenefit New benefit value in basis points
     */
    function updateBadgeBenefit(BadgeType badgeType, uint256 newBenefit) external onlyOwner {
        require(newBenefit <= 10000, "Benefit cannot exceed 100%");
        badgeBenefits[badgeType] = newBenefit;
        emit BenefitUpdated(badgeType, newBenefit);
    }

    /**
     * @dev Get the total discount percentage for an address (sum of all badge benefits)
     * @param user Address to check benefits for
     * @return Total benefit in basis points
     */
    function getTotalBenefits(address user) external view returns (uint256) {
        uint256 totalBenefit = 0;

        for (uint256 i = 0; i <= uint256(type(BadgeType).max); i++) {
            BadgeType badgeType = BadgeType(i);
            if (hasBadge[user][badgeType]) {
                totalBenefit += badgeBenefits[badgeType];
            }
        }

        // Cap total benefit at 25%
        return totalBenefit > 2500 ? 2500 : totalBenefit;
    }

    /**
     * @dev Check if an address has a specific badge
     * @param user Address to check
     * @param badgeType Type of badge to check for
     * @return bool Whether the address has the badge
     */
    function hasSpecificBadge(address user, BadgeType badgeType) external view returns (bool) {
        return hasBadge[user][badgeType];
    }
}
