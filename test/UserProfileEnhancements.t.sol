// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {UserProfile} from "../src/UserProfile.sol";

contract UserProfileEnhancementsTest is Test {
    UserProfile public userProfile;
    address public user1;
    address public user2;
    address public user3;
    address public admin;
    address public verifier;

    event FollowUser(address indexed follower, address indexed followed);
    event UnfollowUser(address indexed follower, address indexed unfollowed);
    event EndorsementAdded(address indexed endorser, address indexed endorsed, string skill);
    event EndorsementRemoved(address indexed endorser, address indexed endorsed, string skill);
    event VerificationTypeAdded(string verificationType);
    event ProfileVerificationUpdated(address indexed user, string verificationType, bool verified);

    function setUp() public {
        admin = makeAddr("admin");
        vm.startPrank(admin);

        userProfile = new UserProfile();
        verifier = makeAddr("verifier");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        userProfile.grantRole(userProfile.VERIFIER_ROLE(), verifier);
        userProfile.grantRole(userProfile.DEFAULT_ADMIN_ROLE(), admin);

        vm.stopPrank();

        // Create profiles for testing
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");
        vm.stopPrank();

        vm.startPrank(user2);
        userProfile.createProfile("bob", "Smart contract developer", "ipfs://metadata2");
        vm.stopPrank();

        vm.startPrank(user3);
        userProfile.createProfile("charlie", "Frontend developer", "ipfs://metadata3");
        vm.stopPrank();
    }

    // Social Graph Tests

    function test_FollowUser() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, false, true);
        emit FollowUser(user1, user2);

        userProfile.followUser(user2);

        assertTrue(userProfile.checkFollowing(user1, user2));
        assertEq(userProfile.followingCount(user1), 1);
        assertEq(userProfile.followersCount(user2), 1);

        address[] memory following = userProfile.getFollowing(user1);
        assertEq(following.length, 1);
        assertEq(following[0], user2);
        vm.stopPrank();
    }

    function test_UnfollowUser() public {
        vm.startPrank(user1);
        userProfile.followUser(user2);

        vm.expectEmit(true, true, false, true);
        emit UnfollowUser(user1, user2);

        userProfile.unfollowUser(user2);

        assertFalse(userProfile.checkFollowing(user1, user2));
        assertEq(userProfile.followingCount(user1), 0);
        assertEq(userProfile.followersCount(user2), 0);
        vm.stopPrank();
    }

    function testFail_FollowYourself() public {
        vm.prank(user1);
        userProfile.followUser(user1);
    }

    // Endorsement Tests

    function test_AddEndorsement() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, false, true);
        emit EndorsementAdded(user1, user2, "Solidity");

        userProfile.addEndorsement(user2, "Solidity", "Great Solidity developer");

        UserProfile.Endorsement[] memory endorsements = userProfile.getEndorsements(user2);
        assertEq(endorsements.length, 1);
        assertEq(endorsements[0].skill, "Solidity");
        assertEq(endorsements[0].endorser, user1);
        assertEq(userProfile.getSkillEndorsementCount(user2, "Solidity"), 1);
        vm.stopPrank();
    }

    function test_RemoveEndorsement() public {
        vm.startPrank(user1);
        userProfile.addEndorsement(user2, "Solidity", "Great Solidity developer");

        vm.expectEmit(true, true, false, true);
        emit EndorsementRemoved(user1, user2, "Solidity");

        userProfile.removeEndorsement(user2, "Solidity");

        UserProfile.Endorsement[] memory endorsements = userProfile.getEndorsements(user2);
        assertEq(endorsements.length, 0);
        assertEq(userProfile.getSkillEndorsementCount(user2, "Solidity"), 0);
        vm.stopPrank();
    }

    function testFail_EndorseYourself() public {
        vm.prank(user1);
        userProfile.addEndorsement(user1, "Solidity", "Self endorsement");
    }

    // Enhanced Verification Tests

    function test_AddVerificationType() public {
        vm.startPrank(admin);

        vm.expectEmit(true, false, false, true);
        emit VerificationTypeAdded("KYC");

        userProfile.addVerificationType("KYC");
        assertTrue(userProfile.supportedVerificationTypes("KYC"));
        vm.stopPrank();
    }

    function test_VerifyProfileEnhanced() public {
        vm.prank(admin);
        userProfile.addVerificationType("KYC");

        vm.startPrank(verifier);

        vm.expectEmit(true, false, false, true);
        emit ProfileVerificationUpdated(user1, "KYC", true);

        userProfile.verifyProfileEnhanced(user1, "KYC", "ipfs://verification-docs");

        UserProfile.VerificationData memory data = userProfile.getVerificationDetails(user1);
        assertTrue(data.isVerified);
        assertEq(data.verificationType, "KYC");
        assertEq(data.verificationProof, "ipfs://verification-docs");
        assertEq(data.verifier, verifier);
        vm.stopPrank();
    }

    function test_RevokeVerification() public {
        vm.prank(admin);
        userProfile.addVerificationType("KYC");

        vm.startPrank(verifier);
        userProfile.verifyProfileEnhanced(user1, "KYC", "ipfs://verification-docs");

        vm.expectEmit(true, false, false, true);
        emit ProfileVerificationUpdated(user1, "KYC", false);

        userProfile.revokeVerification(user1, "KYC");

        UserProfile.VerificationData memory data = userProfile.getVerificationDetails(user1);
        assertFalse(data.isVerified);
        vm.stopPrank();
    }

    function testFail_VerifyWithUnsupportedType() public {
        vm.prank(verifier);
        userProfile.verifyProfileEnhanced(user1, "UNSUPPORTED", "ipfs://verification-docs");
    }

    function testFail_UnauthorizedVerification() public {
        vm.prank(admin);
        userProfile.addVerificationType("KYC");

        vm.prank(user1); // user1 is not a verifier
        userProfile.verifyProfileEnhanced(user2, "KYC", "ipfs://verification-docs");
    }
}
