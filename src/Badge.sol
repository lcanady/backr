// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Badge
 * @dev NFT-based badge system for platform achievements
 */
contract Badge is ERC721, Ownable {
    uint256 private _tokenIds;

    // Badge types and their requirements
    enum BadgeType {
        EARLY_SUPPORTER,      // First 100 users to back a project
        POWER_BACKER,         // Backed more than 5 projects
        LIQUIDITY_PROVIDER,   // Provided significant liquidity
        GOVERNANCE_ACTIVE     // Participated in multiple proposals
    }

    // Mapping from token ID to badge type
    mapping(uint256 => BadgeType) public badgeTypes;
    
    // Mapping from address to badge type to whether they have earned it
    mapping(address => mapping(BadgeType => bool)) public hasBadge;
    
    // Mapping from badge type to its benefits multiplier (in basis points, 100 = 1%)
    mapping(BadgeType => uint256) public badgeBenefits;

    event BadgeAwarded(address indexed recipient, BadgeType badgeType, uint256 tokenId);
    event BenefitUpdated(BadgeType badgeType, uint256 newBenefit);

    constructor() ERC721("Platform Achievement Badge", "BADGE") Ownable() {
        _tokenIds = 0;
        // Set initial badge benefits
        badgeBenefits[BadgeType.EARLY_SUPPORTER] = 500;     // 5% discount
        badgeBenefits[BadgeType.POWER_BACKER] = 1000;       // 10% discount
        badgeBenefits[BadgeType.LIQUIDITY_PROVIDER] = 1500; // 15% discount
        badgeBenefits[BadgeType.GOVERNANCE_ACTIVE] = 750;   // 7.5% discount
    }

    /**
     * @dev Award a badge to an address
     * @param recipient Address to receive the badge
     * @param badgeType Type of badge to award
     */
    function awardBadge(address recipient, BadgeType badgeType) external onlyOwner {
        require(!hasBadge[recipient][badgeType], "Badge already awarded");

        _tokenIds++;
        uint256 newTokenId = _tokenIds;
        
        _safeMint(recipient, newTokenId);
        badgeTypes[newTokenId] = badgeType;
        hasBadge[recipient][badgeType] = true;

        emit BadgeAwarded(recipient, badgeType, newTokenId);
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
        
        for (uint i = 0; i <= uint(type(BadgeType).max); i++) {
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
