// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PlatformToken} from "../src/PlatformToken.sol";

contract PlatformTokenTest is Test {
    PlatformToken public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(owner);
        token = new PlatformToken();
        vm.stopPrank();
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 1_000_000 * 10 ** 18);
    }

    function test_Transfer() public {
        vm.startPrank(owner);
        token.transfer(user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
        vm.stopPrank();
    }

    function test_Approve() public {
        vm.startPrank(owner);
        token.approve(user1, 1000);
        assertEq(token.allowance(owner, user1), 1000);
        vm.stopPrank();
    }

    function test_TransferFrom() public {
        vm.startPrank(owner);
        token.approve(user1, 1000);
        vm.stopPrank();

        vm.startPrank(user1);
        token.transferFrom(owner, user2, 500);
        assertEq(token.balanceOf(user2), 500);
        assertEq(token.allowance(owner, user1), 500);
        vm.stopPrank();
    }

    function test_Staking() public {
        // Transfer some tokens to user1
        vm.startPrank(owner);
        token.transfer(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        // Stake tokens
        vm.startPrank(user1);
        token.stake(500 * 10 ** 18);
        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
        assertEq(token.stakedBalance(user1), 500 * 10 ** 18);

        // Warp time forward by 1 year
        vm.warp(block.timestamp + 365 days);

        // Unstake and check rewards
        token.unstake();
        // Should receive original stake (500) plus 5% annual reward (25)
        assertEq(token.balanceOf(user1), 1050 * 10 ** 18); // 500 + 500 + (500 * 5%) = 1050
        assertEq(token.stakedBalance(user1), 0);
        vm.stopPrank();
    }

    function testFail_UnstakeBeforeMinDuration() public {
        vm.startPrank(owner);
        token.transfer(user1, 1000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(user1);
        token.stake(500 * 10 ** 18);
        // Try to unstake immediately
        token.unstake();
        vm.stopPrank();
    }
}
