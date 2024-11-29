// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Badge.sol";

contract BadgeTest is Test {
    Badge public badge;
    address public owner;
    address public alice;
    address public bob;

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        badge = new Badge();
    }

    function testAwardBadge() public {
        vm.startPrank(owner);
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        assertTrue(badge.hasBadge(alice, Badge.BadgeType.EARLY_SUPPORTER));
        vm.stopPrank();
    }

    function testFailDuplicateBadge() public {
        vm.startPrank(owner);
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        vm.stopPrank();
    }

    function testUpdateBadgeBenefit() public {
        uint256 newBenefit = 2000; // 20%
        badge.updateBadgeBenefit(Badge.BadgeType.EARLY_SUPPORTER, newBenefit);

        // Award badge to alice
        vm.startPrank(owner);
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        vm.stopPrank();

        // Check total benefits
        assertEq(badge.getTotalBenefits(alice), newBenefit);
    }

    function testMultipleBadgeBenefits() public {
        // Award multiple badges to alice
        vm.startPrank(owner);
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        badge.awardBadge(alice, Badge.BadgeType.POWER_BACKER, "ipfs://badge/power-backer");
        vm.stopPrank();

        // Calculate expected benefits (5% + 10% = 15%)
        uint256 expectedBenefit = 1500;

        assertEq(badge.getTotalBenefits(alice), expectedBenefit);
    }

    function testBenefitsCap() public {
        // Award all badges to alice
        vm.startPrank(owner);
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        badge.awardBadge(alice, Badge.BadgeType.POWER_BACKER, "ipfs://badge/power-backer");
        badge.awardBadge(alice, Badge.BadgeType.LIQUIDITY_PROVIDER, "ipfs://badge/liquidity-provider");
        badge.awardBadge(alice, Badge.BadgeType.GOVERNANCE_ACTIVE, "ipfs://badge/governance-active");
        vm.stopPrank();

        // Total would be 37.5%, but should be capped at 25%
        assertEq(badge.getTotalBenefits(alice), 2500);
    }

    function testFailUnauthorizedAward() public {
        vm.startPrank(alice);
        badge.awardBadge(bob, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        vm.stopPrank();
    }

    function testFailExcessiveBenefit() public {
        // Try to set benefit higher than 100%
        badge.updateBadgeBenefit(Badge.BadgeType.EARLY_SUPPORTER, 10001);
    }

    function testUpdateGovernanceWeight() public {
        uint256 newWeight = 3000; // 30x voting power
        badge.updateGovernanceWeight(Badge.BadgeType.EARLY_SUPPORTER, newWeight);

        // Award badge to alice
        vm.startPrank(owner);
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        vm.stopPrank();

        // Base weight (1x) + new weight (30x)
        assertEq(badge.getGovernanceWeight(alice), 100 + newWeight);
    }

    function testMultipleBadgeGovernanceWeights() public {
        // Award multiple badges to alice
        vm.startPrank(owner);
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
        badge.awardBadge(alice, Badge.BadgeType.GOVERNANCE_ACTIVE, "ipfs://badge/governance-active");
        vm.stopPrank();

        // Calculate expected weight (base 1x + 10x + 20x)
        uint256 expectedWeight = 100 + 1000 + 2000;
        assertEq(badge.getGovernanceWeight(alice), expectedWeight);
    }

    function testTierBonusGovernanceWeight() public {
        vm.startPrank(owner);
        // Award POWER_BACKER badge to alice
        badge.awardBadge(alice, Badge.BadgeType.POWER_BACKER, "ipfs://badge/power-backer");

        // Record actions to reach SILVER tier
        for (uint256 i = 0; i < 10; i++) {
            badge.recordAction(alice, Badge.BadgeType.POWER_BACKER);
        }
        vm.stopPrank();

        // Base weight (1x) + POWER_BACKER weight (5x) with SILVER tier bonus (25%)
        // 100 + (500 * 125 / 100) = 100 + 625 = 725
        assertEq(badge.getGovernanceWeight(alice), 725);
    }

    function testFailExcessiveGovernanceWeight() public {
        // Try to set weight higher than 100x
        badge.updateGovernanceWeight(Badge.BadgeType.EARLY_SUPPORTER, 10001);
    }
}
