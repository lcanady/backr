// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Badge.sol";
import "../src/BadgeMarketplace.sol";

contract BadgeMarketplaceTest is Test {
    Badge public badge;
    BadgeMarketplace public marketplace;
    address public owner;
    address public alice;
    address public bob;

    uint256 public constant BADGE_PRICE = 1 ether;
    uint256 public constant FUTURE_TIME = 1893456000; // 2030-01-01

    function setUp() public {
        owner = address(this);
        alice = address(0x1);
        bob = address(0x2);

        // Give alice and bob some ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        badge = new Badge();
        marketplace = new BadgeMarketplace(address(badge));

        // Award a badge to alice
        badge.awardBadge(alice, Badge.BadgeType.EARLY_SUPPORTER, "ipfs://badge/early-supporter");
    }

    function testListBadge() public {
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, 0);

        (address seller, uint256 price, uint256 expiry) = marketplace.listings(1);
        assertEq(seller, alice);
        assertEq(price, BADGE_PRICE);
        assertEq(expiry, 0);
        vm.stopPrank();
    }

    function testListTimeLimitedBadge() public {
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, FUTURE_TIME);

        (address seller, uint256 price, uint256 expiry) = marketplace.listings(1);
        assertEq(seller, alice);
        assertEq(price, BADGE_PRICE);
        assertEq(expiry, FUTURE_TIME);
        vm.stopPrank();
    }

    function testPurchaseBadge() public {
        // List badge
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, 0);
        vm.stopPrank();

        // Purchase badge
        vm.startPrank(bob);
        marketplace.purchaseBadge{value: BADGE_PRICE}(1);

        // Verify ownership transfer
        assertEq(badge.ownerOf(1), bob);

        // Verify alice received payment
        assertEq(alice.balance, 11 ether);
        vm.stopPrank();
    }

    function testPurchaseTimeLimitedBadge() public {
        // List badge with future expiry
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, FUTURE_TIME);
        vm.stopPrank();

        // Purchase badge
        vm.startPrank(bob);
        marketplace.purchaseBadge{value: BADGE_PRICE}(1);
        assertEq(badge.ownerOf(1), bob);
        vm.stopPrank();
    }

    function testFailPurchaseExpiredBadge() public {
        // List badge with future expiry
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, block.timestamp + 1 hours);
        vm.stopPrank();

        // Warp time past expiry
        vm.warp(block.timestamp + 2 hours);

        // Try to purchase expired badge
        vm.startPrank(bob);
        marketplace.purchaseBadge{value: BADGE_PRICE}(1);
        vm.stopPrank();
    }

    function testUnlistBadge() public {
        // List badge
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, 0);

        // Unlist badge
        marketplace.unlistBadge(1);

        // Verify listing is removed
        (address seller, uint256 price,) = marketplace.listings(1);
        assertEq(seller, address(0));
        assertEq(price, 0);
        vm.stopPrank();
    }

    function testGetActiveListings() public {
        // List multiple badges
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, 0);
        vm.stopPrank();

        // Award and list another badge
        badge.awardBadge(bob, Badge.BadgeType.POWER_BACKER, "ipfs://badge/power-backer");
        vm.startPrank(bob);
        badge.approve(address(marketplace), 2);
        marketplace.listBadge(2, BADGE_PRICE * 2, FUTURE_TIME);
        vm.stopPrank();

        // Get active listings
        (uint256[] memory tokenIds, uint256[] memory prices, address[] memory sellers, uint256[] memory expiries) =
            marketplace.getActiveListings();

        // Verify listings
        assertEq(tokenIds.length, 2);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(prices[0], BADGE_PRICE);
        assertEq(prices[1], BADGE_PRICE * 2);
        assertEq(sellers[0], alice);
        assertEq(sellers[1], bob);
        assertEq(expiries[0], 0);
        assertEq(expiries[1], FUTURE_TIME);
    }

    function testFailUnauthorizedUnlist() public {
        // List badge as alice
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, 0);
        vm.stopPrank();

        // Try to unlist as bob
        vm.startPrank(bob);
        marketplace.unlistBadge(1);
        vm.stopPrank();
    }

    function testFailInsufficientPayment() public {
        // List badge
        vm.startPrank(alice);
        badge.approve(address(marketplace), 1);
        marketplace.listBadge(1, BADGE_PRICE, 0);
        vm.stopPrank();

        // Try to purchase with insufficient payment
        vm.startPrank(bob);
        marketplace.purchaseBadge{value: BADGE_PRICE - 0.1 ether}(1);
        vm.stopPrank();
    }

    receive() external payable {}
}
