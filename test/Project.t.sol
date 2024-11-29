// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Project.sol";
import "../src/UserProfile.sol";

contract ProjectTest is Test {
    Project public project;
    UserProfile public userProfile;

    address public admin;
    address public creator;
    address public backer;
    address public emergency;

    function setUp() public {
        admin = makeAddr("admin");
        creator = makeAddr("creator");
        backer = makeAddr("backer");
        emergency = makeAddr("emergency");

        vm.startPrank(admin);
        userProfile = new UserProfile();
        project = new Project(address(userProfile));

        // Setup roles
        project.grantRole(project.EMERGENCY_ROLE(), emergency);
        project.grantRole(project.OPERATOR_ROLE(), admin);

        // Set shorter emergency cooldown for testing
        project.setEmergencyCooldownPeriod(1 seconds);
        vm.stopPrank();

        // Setup user profiles
        vm.startPrank(creator);
        userProfile.createProfile("creator", "Project Creator", "ipfs://creator");
        vm.stopPrank();

        vm.startPrank(backer);
        userProfile.createProfile("backer", "Project Backer", "ipfs://backer");
        vm.stopPrank();

        // Fund accounts
        vm.deal(backer, 100 ether);
    }

    function test_CreateProject() public {
        string[] memory descriptions = new string[](2);
        descriptions[0] = "Milestone 1";
        descriptions[1] = "Milestone 2";

        uint256[] memory funding = new uint256[](2);
        funding[0] = 1 ether;
        funding[1] = 2 ether;

        uint256[] memory votes = new uint256[](2);
        votes[0] = 5;
        votes[1] = 8;

        vm.startPrank(creator);
        project.createProject("Test Project", "Description", descriptions, funding, votes);

        // Try to create another project immediately (should fail due to rate limit)
        vm.expectRevert("Rate limit exceeded");
        project.createProject("Test Project 2", "Description", descriptions, funding, votes);
        vm.stopPrank();

        // Should work after 24 hours
        vm.warp(block.timestamp + 24 hours + 1);
        vm.prank(creator);
        project.createProject("Test Project 2", "Description", descriptions, funding, votes);
    }

    function test_EmergencyWithdrawal() public {
        // Setup and fund project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 5 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 5;

        vm.prank(creator);
        project.createProject("Test Project", "Description", descriptions, funding, votes);

        vm.prank(backer);
        project.contributeToProject{value: 5 ether}(0);

        // Trigger emergency
        vm.prank(emergency);
        project.triggerEmergency("Security incident");

        // Wait for cooldown period
        vm.warp(block.timestamp + 1 seconds);

        // Perform emergency withdrawal
        uint256 creatorBalanceBefore = creator.balance;
        vm.prank(emergency);
        project.emergencyWithdraw(0);

        assertEq(creator.balance - creatorBalanceBefore, 5 ether);

        // Get project details
        (,,,, uint256 currentFunding,, bool isActive,) = project.projects(0);
        assertEq(currentFunding, 0);
        assertFalse(isActive);
    }

    function test_CircuitBreaker() public {
        // Setup project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 5 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 5;

        vm.prank(creator);
        project.createProject("Test Project", "Description", descriptions, funding, votes);

        // Trigger circuit breaker
        vm.prank(emergency);
        project.triggerEmergency("Security incident");

        // Try to perform actions while paused
        vm.startPrank(backer);
        vm.expectRevert("Pausable: paused");
        project.contributeToProject{value: 1 ether}(0);

        vm.expectRevert("Pausable: paused");
        project.voteMilestone(0, 0);
        vm.stopPrank();

        // Wait for cooldown
        vm.warp(block.timestamp + 1 seconds);

        // Resolve emergency
        vm.prank(emergency);
        project.resolveEmergency();

        // Actions should work again
        vm.prank(backer);
        project.contributeToProject{value: 1 ether}(0);

        // Verify project is active
        (,,,,,, bool isActive,) = project.projects(0);
        assertTrue(isActive);
    }

    function test_LargeFundingWithMultiSig() public {
        // Setup project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 15 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 5;

        vm.prank(creator);
        project.createProject("Test Project", "Description", descriptions, funding, votes);

        // Setup multi-sig
        vm.startPrank(admin);
        address[] memory approvers = new address[](2);
        approvers[0] = admin;
        approvers[1] = emergency;
        project.configureMultiSig(project.LARGE_FUNDING_OPERATION(), 2, approvers);
        vm.stopPrank();

        // Prepare large funding contribution
        uint256 contributionAmount = 12 ether;
        bytes32 txHash = keccak256(abi.encodePacked(bytes32(0), backer, contributionAmount, block.timestamp));

        // Approve by both admin and emergency role
        vm.startPrank(admin);
        project.approveOperation(project.LARGE_FUNDING_OPERATION(), txHash);
        vm.stopPrank();

        vm.startPrank(emergency);
        project.approveOperation(project.LARGE_FUNDING_OPERATION(), txHash);
        vm.stopPrank();

        // Now funding should work
        vm.prank(backer);
        project.contributeToProject{value: contributionAmount}(0);
    }

    function test_ContributeToProject() public {
        // Create project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 2;

        vm.startPrank(creator);
        project.createProject("Test", "Description", descriptions, funding, votes);
        vm.stopPrank();

        // Contribute
        vm.deal(backer, 2 ether);
        vm.startPrank(backer);
        project.contributeToProject{value: 1 ether}(0);
    }

    function test_CompleteMilestone() public {
        // Create project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 2;

        vm.startPrank(creator);
        project.createProject("Test", "Description", descriptions, funding, votes);
        vm.stopPrank();

        // Fund project
        vm.deal(backer, 2 ether);
        vm.startPrank(backer);
        project.contributeToProject{value: 1 ether}(0);
        project.voteMilestone(0, 0);
        vm.stopPrank();

        // Second vote to complete milestone
        vm.startPrank(creator);
        project.voteMilestone(0, 0);
        vm.stopPrank();

        // Check milestone completion
        (,,,, bool completed) = project.getMilestone(0, 0);
        assertTrue(completed);
    }

    function testFail_DoubleVote() public {
        // Create project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 2;

        vm.startPrank(creator);
        project.createProject("Test", "Description", descriptions, funding, votes);
        vm.stopPrank();

        vm.startPrank(backer);
        project.voteMilestone(0, 0);
        project.voteMilestone(0, 0); // Should fail
    }

    function testFail_CreateProjectWithoutProfile() public {
        address noProfile = makeAddr("noProfile");
        string[] memory descriptions = new string[](1);
        uint256[] memory funding = new uint256[](1);
        uint256[] memory votes = new uint256[](1);

        vm.startPrank(noProfile);
        project.createProject("Test", "Description", descriptions, funding, votes);
    }
}
