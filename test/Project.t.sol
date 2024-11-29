// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Project} from "../src/Project.sol";
import {UserProfile} from "../src/UserProfile.sol";

contract ProjectTest is Test {
    Project public project;
    UserProfile public userProfile;

    address public creator;
    address public contributor1;
    address public contributor2;

    function setUp() public {
        creator = makeAddr("creator");
        contributor1 = makeAddr("contributor1");
        contributor2 = makeAddr("contributor2");

        // Deploy contracts
        userProfile = new UserProfile();
        project = new Project(address(userProfile));

        // Create user profiles
        vm.startPrank(creator);
        userProfile.createProfile("creator", "Project Creator", "ipfs://creator");
        vm.stopPrank();

        vm.startPrank(contributor1);
        userProfile.createProfile("contributor1", "Project Contributor 1", "ipfs://contributor1");
        vm.stopPrank();

        vm.startPrank(contributor2);
        userProfile.createProfile("contributor2", "Project Contributor 2", "ipfs://contributor2");
        vm.stopPrank();
    }

    function test_CreateProject() public {
        string[] memory descriptions = new string[](2);
        descriptions[0] = "Milestone 1";
        descriptions[1] = "Milestone 2";

        uint256[] memory funding = new uint256[](2);
        funding[0] = 1 ether;
        funding[1] = 2 ether;

        uint256[] memory votes = new uint256[](2);
        votes[0] = 2;
        votes[1] = 3;

        vm.startPrank(creator);
        project.createProject("Test Project", "A test project description", descriptions, funding, votes);

        (string memory desc, uint256 fundingReq, uint256 votesReq, uint256 votesRec, bool completed) =
            project.getMilestone(0, 0);

        assertEq(desc, "Milestone 1");
        assertEq(fundingReq, 1 ether);
        assertEq(votesReq, 2);
        assertEq(votesRec, 0);
        assertEq(completed, false);
    }

    function testFail_CreateProjectWithoutProfile() public {
        address noProfile = makeAddr("noProfile");
        string[] memory descriptions = new string[](1);
        uint256[] memory funding = new uint256[](1);
        uint256[] memory votes = new uint256[](1);

        vm.startPrank(noProfile);
        project.createProject("Test", "Description", descriptions, funding, votes);
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
        vm.deal(contributor1, 2 ether);
        vm.startPrank(contributor1);
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
        vm.deal(contributor1, 2 ether);
        vm.startPrank(contributor1);
        project.contributeToProject{value: 1 ether}(0);
        project.voteMilestone(0, 0);
        vm.stopPrank();

        // Second vote to complete milestone
        vm.startPrank(contributor2);
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

        vm.startPrank(contributor1);
        project.voteMilestone(0, 0);
        project.voteMilestone(0, 0); // Should fail
    }
}
