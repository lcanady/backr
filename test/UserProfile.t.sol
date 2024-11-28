// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {UserProfile} from "../src/UserProfile.sol";

contract UserProfileTest is Test {
    UserProfile public userProfile;
    address public user1;
    address public user2;

    function setUp() public {
        userProfile = new UserProfile();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
    }

    function test_CreateProfile() public {
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer");
        
        UserProfile.Profile memory profile = userProfile.getProfile(user1);
        assertEq(profile.username, "alice");
        assertEq(profile.bio, "Web3 developer");
        assertEq(profile.reputationScore, 0);
        assertTrue(profile.isRegistered);
    }

    function testFail_CreateDuplicateProfile() public {
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer");
        userProfile.createProfile("alice2", "Another bio"); // Should fail
    }

    function test_UpdateProfile() public {
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer");
        userProfile.updateProfile("alice_updated", "Senior Web3 developer");
        
        UserProfile.Profile memory profile = userProfile.getProfile(user1);
        assertEq(profile.username, "alice_updated");
        assertEq(profile.bio, "Senior Web3 developer");
    }

    function testFail_UpdateNonExistentProfile() public {
        vm.startPrank(user1);
        userProfile.updateProfile("alice", "Web3 developer"); // Should fail
    }

    function test_HasProfile() public {
        assertFalse(userProfile.hasProfile(user1));
        
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer");
        assertTrue(userProfile.hasProfile(user1));
    }

    function test_TotalUsers() public {
        assertEq(userProfile.totalUsers(), 0);
        
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer");
        assertEq(userProfile.totalUsers(), 1);
        
        vm.startPrank(user2);
        userProfile.createProfile("bob", "Smart contract developer");
        assertEq(userProfile.totalUsers(), 2);
    }
}
