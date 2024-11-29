// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {UserProfile} from "../src/UserProfile.sol";

contract UserProfileTest is Test {
    UserProfile public userProfile;
    address public user1;
    address public user2;
    address public admin;
    address public verifier;
    address public reputationManager;

    event ProfileCreated(address indexed user, string username);
    event ProfileUpdated(address indexed user);
    event ReputationUpdated(address indexed user, uint256 newScore);
    event ProfileVerified(address indexed user);
    event RecoveryAddressSet(address indexed user, address indexed recoveryAddress);
    event RecoveryRequested(address indexed user, uint256 requestTime);
    event RecoveryExecuted(address indexed oldAddress, address indexed newAddress);
    event MetadataUpdated(address indexed user, string metadata);

    function setUp() public {
        admin = makeAddr("admin");
        vm.startPrank(admin);

        userProfile = new UserProfile();

        verifier = makeAddr("verifier");
        reputationManager = makeAddr("reputationManager");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        userProfile.grantRole(userProfile.VERIFIER_ROLE(), verifier);
        userProfile.grantRole(userProfile.REPUTATION_MANAGER_ROLE(), reputationManager);

        vm.stopPrank();
    }

    function test_CreateProfile() public {
        vm.startPrank(user1);

        vm.expectEmit(true, false, false, true);
        emit ProfileCreated(user1, "alice");

        vm.expectEmit(true, false, false, true);
        emit MetadataUpdated(user1, "ipfs://metadata1");

        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        UserProfile.Profile memory profile = userProfile.getProfile(user1);
        assertEq(profile.username, "alice");
        assertEq(profile.bio, "Web3 developer");
        assertEq(profile.metadata, "ipfs://metadata1");
        assertEq(profile.reputationScore, 0);
        assertTrue(profile.isRegistered);
        assertFalse(profile.isVerified);
        assertEq(profile.recoveryAddress, address(0));
        assertEq(profile.recoveryRequestTime, 0);
    }

    function testFail_CreateDuplicateProfile() public {
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");
        userProfile.createProfile("alice2", "Another bio", "ipfs://metadata2"); // Should fail
    }

    function testFail_CreateDuplicateUsername() public {
        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        vm.prank(user2);
        userProfile.createProfile("alice", "Different bio", "ipfs://metadata2"); // Should fail
    }

    function test_UpdateProfile() public {
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        // Wait for cooldown
        skip(1 days + 1);

        vm.expectEmit(true, false, false, true);
        emit ProfileUpdated(user1);

        vm.expectEmit(true, false, false, true);
        emit MetadataUpdated(user1, "ipfs://metadata2");

        userProfile.updateProfile("alice_updated", "Senior Web3 developer", "ipfs://metadata2");

        UserProfile.Profile memory profile = userProfile.getProfile(user1);
        assertEq(profile.username, "alice_updated");
        assertEq(profile.bio, "Senior Web3 developer");
        assertEq(profile.metadata, "ipfs://metadata2");
    }

    function testFail_UpdateProfileTooSoon() public {
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        // Try to update before cooldown
        userProfile.updateProfile("alice_updated", "Senior Web3 developer", "ipfs://metadata2");
    }

    function test_UpdateReputation() public {
        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        vm.startPrank(reputationManager);

        vm.expectEmit(true, false, false, true);
        emit ReputationUpdated(user1, 100);

        userProfile.updateReputation(user1, 100);

        UserProfile.Profile memory profile = userProfile.getProfile(user1);
        assertEq(profile.reputationScore, 100);
    }

    function testFail_UpdateReputationUnauthorized() public {
        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        vm.prank(user2);
        userProfile.updateReputation(user1, 100); // Should fail
    }

    function test_VerifyProfile() public {
        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        vm.startPrank(verifier);

        vm.expectEmit(true, false, false, true);
        emit ProfileVerified(user1);

        userProfile.verifyProfile(user1);

        UserProfile.Profile memory profile = userProfile.getProfile(user1);
        assertTrue(profile.isVerified);
    }

    function testFail_VerifyProfileUnauthorized() public {
        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        vm.prank(user2);
        userProfile.verifyProfile(user1); // Should fail
    }

    function test_ProfileRecovery() public {
        // Create profile
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        // Set recovery address
        vm.expectEmit(true, true, false, true);
        emit RecoveryAddressSet(user1, user2);

        userProfile.setRecoveryAddress(user2);

        vm.stopPrank();

        // Initiate recovery
        vm.startPrank(user2);

        vm.expectEmit(true, false, false, true);
        emit RecoveryRequested(user1, block.timestamp);

        userProfile.initiateRecovery(user1);

        // Wait for delay
        skip(3 days + 1);

        vm.expectEmit(true, true, false, true);
        emit RecoveryExecuted(user1, user2);

        userProfile.executeRecovery(user1);

        // Verify profile was transferred
        UserProfile.Profile memory profile = userProfile.getProfile(user2);
        assertEq(profile.username, "alice");
        assertEq(profile.bio, "Web3 developer");

        // Verify old profile was deleted
        vm.expectRevert();
        userProfile.getProfile(user1);
    }

    function test_GetProfileByUsername() public {
        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        UserProfile.Profile memory profile = userProfile.getProfileByUsername("alice");
        assertEq(profile.username, "alice");
        assertEq(profile.bio, "Web3 developer");
    }

    function test_PauseUnpause() public {
        vm.startPrank(admin);
        userProfile.pause();

        vm.expectRevert();
        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        vm.prank(admin);
        userProfile.unpause();

        vm.prank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");
    }

    function test_HasProfile() public {
        assertFalse(userProfile.hasProfile(user1));

        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");
        assertTrue(userProfile.hasProfile(user1));
    }

    function test_TotalUsers() public {
        assertEq(userProfile.totalUsers(), 0);

        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");
        assertEq(userProfile.totalUsers(), 1);

        vm.startPrank(user2);
        userProfile.createProfile("bob", "Smart contract developer", "ipfs://metadata2");
        assertEq(userProfile.totalUsers(), 2);
    }
}
