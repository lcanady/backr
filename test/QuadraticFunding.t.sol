// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {QuadraticFunding} from "../src/QuadraticFunding.sol";
import {Project} from "../src/Project.sol";
import {UserProfile} from "../src/UserProfile.sol";

contract QuadraticFundingTest is Test {
    QuadraticFunding public qf;
    Project public project;
    UserProfile public userProfile;

    address public admin;
    address public creator;
    address public contributor1;
    address public contributor2;

    function setUp() public {
        admin = makeAddr("admin");
        creator = makeAddr("creator");
        contributor1 = makeAddr("contributor1");
        contributor2 = makeAddr("contributor2");

        vm.startPrank(admin);
        // Deploy contracts
        userProfile = new UserProfile();
        project = new Project(address(userProfile));
        qf = new QuadraticFunding(payable(address(project)));
        vm.stopPrank();

        // Create user profiles
        vm.startPrank(creator);
        userProfile.createProfile("creator", "Project Creator", "ipfs://creator");
        vm.stopPrank();

        vm.startPrank(contributor1);
        userProfile.createProfile("contributor1", "Contributor 1", "ipfs://contributor1");
        vm.stopPrank();

        vm.startPrank(contributor2);
        userProfile.createProfile("contributor2", "Contributor 2", "ipfs://contributor2");
        vm.stopPrank();

        // Create a test project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 2;

        vm.startPrank(creator);
        project.createProject("Test Project", "Description", descriptions, funding, votes);
        vm.stopPrank();
    }

    function test_StartRound() public {
        vm.deal(admin, 10 ether);
        vm.startPrank(admin);

        QuadraticFunding.RoundConfig memory config = QuadraticFunding.RoundConfig({
            startTime: block.timestamp,
            endTime: block.timestamp + 14 days,
            minContribution: 0.1 ether,
            maxContribution: 5 ether
        });

        qf.createRound{value: 10 ether}(config);
        assertTrue(qf.isRoundActive());
        vm.stopPrank();
    }

    function testFail_StartRoundWithActiveRound() public {
        vm.deal(admin, 20 ether);
        vm.startPrank(admin);

        QuadraticFunding.RoundConfig memory config = QuadraticFunding.RoundConfig({
            startTime: block.timestamp,
            endTime: block.timestamp + 14 days,
            minContribution: 0.1 ether,
            maxContribution: 5 ether
        });

        qf.createRound{value: 10 ether}(config);
        qf.createRound{value: 10 ether}(config); // Should fail
        vm.stopPrank();
    }

    function test_Contribute() public {
        // Start round
        vm.deal(admin, 10 ether);
        vm.startPrank(admin);

        QuadraticFunding.RoundConfig memory config = QuadraticFunding.RoundConfig({
            startTime: block.timestamp,
            endTime: block.timestamp + 14 days,
            minContribution: 0.1 ether,
            maxContribution: 5 ether
        });

        qf.createRound{value: 10 ether}(config);

        // Verify participants after round creation
        qf.verifyParticipant(contributor1, true);
        qf.verifyParticipant(contributor2, true);
        vm.stopPrank();

        // Make contributions
        vm.deal(contributor1, 1 ether);
        vm.startPrank(contributor1);
        qf.contribute{value: 1 ether}(0);
        vm.stopPrank();

        assertEq(qf.getProjectContributions(0, 0), 1 ether);
        assertEq(qf.getContribution(0, 0, contributor1), 1 ether);
    }

    function test_FinalizeRound() public {
        // Start round
        vm.deal(admin, 10 ether);
        vm.startPrank(admin);

        QuadraticFunding.RoundConfig memory config = QuadraticFunding.RoundConfig({
            startTime: block.timestamp,
            endTime: block.timestamp + 14 days,
            minContribution: 0.1 ether,
            maxContribution: 5 ether
        });

        qf.createRound{value: 10 ether}(config);

        // Verify participants after round creation
        qf.verifyParticipant(contributor1, true);
        qf.verifyParticipant(contributor2, true);
        vm.stopPrank();

        // Make contributions
        vm.deal(contributor1, 4 ether);
        vm.startPrank(contributor1);
        qf.contribute{value: 4 ether}(0);
        vm.stopPrank();

        vm.deal(contributor2, 1 ether);
        vm.startPrank(contributor2);
        qf.contribute{value: 1 ether}(1);
        vm.stopPrank();

        // Warp time to end round
        vm.warp(block.timestamp + 15 days);

        // Finalize round
        vm.startPrank(admin);
        qf.finalizeRound();
        vm.stopPrank();

        // Check matching amounts
        uint256 project0Matching = qf.getMatchingAmount(0, 0);
        uint256 project1Matching = qf.getMatchingAmount(0, 1);

        assertTrue(project0Matching > 0);
        assertTrue(project1Matching > 0);
        assertEq(project0Matching + project1Matching, 10 ether);
    }

    function testFail_ContributeInactiveRound() public {
        vm.deal(contributor1, 1 ether);
        vm.startPrank(contributor1);
        qf.contribute{value: 1 ether}(0); // Should fail
        vm.stopPrank();
    }

    function testFail_FinalizeActiveRound() public {
        // Start round
        vm.deal(admin, 10 ether);
        vm.startPrank(admin);

        QuadraticFunding.RoundConfig memory config = QuadraticFunding.RoundConfig({
            startTime: block.timestamp,
            endTime: block.timestamp + 14 days,
            minContribution: 0.1 ether,
            maxContribution: 5 ether
        });

        qf.createRound{value: 10 ether}(config);

        // Try to finalize before round ends
        qf.finalizeRound(); // Should fail
        vm.stopPrank();
    }
}
