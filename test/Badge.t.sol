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
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER);

        assertTrue(badge.hasSpecificBadge(alice, Badge.BadgeType.EARLY_SUPPORTER));
        assertEq(badge.balanceOf(alice), 1);
    }

    function testFailDuplicateBadge() public {
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER);

        // This should fail
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER);
    }

    function testUpdateBadgeBenefit() public {
        uint256 newBenefit = 2000; // 20%
        badge.updateBadgeBenefit(Badge.BadgeType.EARLY_SUPPORTER, newBenefit);

        // Award badge to alice
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER);

        // Check total benefits
        assertEq(badge.getTotalBenefits(alice), newBenefit);
    }

    function testMultipleBadgeBenefits() public {
        // Award multiple badges to alice
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER);
        badge.awardBadge(alice, Badge.BadgeType.POWER_BACKER);

        // Calculate expected benefits (5% + 10% = 15%)
        uint256 expectedBenefit = 1500;

        assertEq(badge.getTotalBenefits(alice), expectedBenefit);
    }

    function testBenefitsCap() public {
        // Award all badges to alice
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER);
        badge.awardBadge(alice, Badge.BadgeType.POWER_BACKER);
        badge.awardBadge(alice, Badge.BadgeType.LIQUIDITY_PROVIDER);
        badge.awardBadge(alice, Badge.BadgeType.GOVERNANCE_ACTIVE);

        // Total would be 37.5%, but should be capped at 25%
        assertEq(badge.getTotalBenefits(alice), 2500);
    }

    function testFailUnauthorizedAward() public {
        vm.prank(alice);
        // This should fail as alice is not the owner
        badge.awardBadge(bob, Badge.BadgeType.EARLY_SUPPORTER);
    }

    function testFailExcessiveBenefit() public {
        // Try to set benefit higher than 100%
        badge.updateBadgeBenefit(Badge.BadgeType.EARLY_SUPPORTER, 10001);
    }
}
