// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Project} from "../../src/Project.sol";
import {UserProfile} from "../../src/UserProfile.sol";
import {ProjectPortfolio} from "../../src/ux/ProjectPortfolio.sol";

contract ProjectPortfolioTest is Test {
    ProjectPortfolio public portfolio;
    Project public project;
    UserProfile public userProfile;

    address public user1;
    address public user2;
    address public admin;
    uint256 public projectId;

    event PortfolioItemAdded(address indexed user, uint256 indexed projectId);
    event PortfolioItemRemoved(address indexed user, uint256 indexed projectId);
    event PortfolioMetadataUpdated(address indexed user);
    event PortfolioItemUpdated(address indexed user, uint256 indexed projectId);

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.startPrank(admin);

        // Deploy contracts
        userProfile = new UserProfile();
        project = new Project(address(userProfile));
        portfolio = new ProjectPortfolio(payable(address(project)), address(userProfile));

        vm.stopPrank();

        // Create user profiles
        vm.startPrank(user1);
        userProfile.createProfile("alice", "Web3 developer", "ipfs://metadata1");

        // Create a test project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 3;

        project.createProject("Test Project", "A test project", descriptions, funding, votes);
        projectId = 0;
        vm.stopPrank();
    }

    function test_AddPortfolioItem() public {
        vm.startPrank(user1);

        string[] memory tags = new string[](2);
        tags[0] = "blockchain";
        tags[1] = "defi";

        vm.expectEmit(true, true, false, true);
        emit PortfolioItemAdded(user1, projectId);

        portfolio.addPortfolioItem(projectId, "My first blockchain project", tags, "ipfs://media1", true);

        ProjectPortfolio.PortfolioItem[] memory items = portfolio.getPortfolioItems(user1);
        assertEq(items.length, 1);
        assertEq(items[0].projectId, projectId);
        assertEq(items[0].featured, true);
        vm.stopPrank();
    }

    function test_RemovePortfolioItem() public {
        vm.startPrank(user1);

        string[] memory tags = new string[](1);
        tags[0] = "blockchain";

        portfolio.addPortfolioItem(projectId, "Description", tags, "ipfs://media1", true);

        vm.expectEmit(true, true, false, true);
        emit PortfolioItemRemoved(user1, projectId);

        portfolio.removePortfolioItem(projectId);

        ProjectPortfolio.PortfolioItem[] memory items = portfolio.getPortfolioItems(user1);
        assertEq(items.length, 0);
        vm.stopPrank();
    }

    function test_UpdatePortfolioMetadata() public {
        vm.startPrank(user1);

        string[] memory skills = new string[](2);
        skills[0] = "Solidity";
        skills[1] = "Web3";

        vm.expectEmit(true, false, false, true);
        emit PortfolioMetadataUpdated(user1);

        portfolio.updatePortfolioMetadata("My Portfolio", "Blockchain Developer Portfolio", skills, true);

        (string memory title, string memory description, string[] memory highlightedSkills, bool isPublic) =
            portfolio.getPortfolioMetadata(user1);

        assertEq(title, "My Portfolio");
        assertEq(description, "Blockchain Developer Portfolio");
        assertTrue(isPublic);
        assertEq(highlightedSkills[0], "Solidity");
        assertEq(highlightedSkills[1], "Web3");
        vm.stopPrank();
    }

    function test_UpdatePortfolioItem() public {
        vm.startPrank(user1);

        string[] memory tags = new string[](1);
        tags[0] = "blockchain";

        portfolio.addPortfolioItem(projectId, "Original description", tags, "ipfs://media1", true);

        string[] memory newTags = new string[](2);
        newTags[0] = "blockchain";
        newTags[1] = "defi";

        vm.expectEmit(true, true, false, true);
        emit PortfolioItemUpdated(user1, projectId);

        portfolio.updatePortfolioItem(projectId, "Updated description", newTags, "ipfs://media2", false);

        ProjectPortfolio.PortfolioItem[] memory items = portfolio.getPortfolioItems(user1);
        assertEq(items[0].description, "Updated description");
        assertEq(items[0].mediaUrl, "ipfs://media2");
        assertEq(items[0].featured, false);
        vm.stopPrank();
    }

    function test_GetFeaturedItems() public {
        vm.startPrank(user1);

        string[] memory tags = new string[](1);
        tags[0] = "blockchain";

        // Add two items, one featured and one not
        portfolio.addPortfolioItem(projectId, "Featured project", tags, "ipfs://media1", true);

        // Advance time to avoid rate limit
        vm.warp(block.timestamp + 1 days);

        // Create another project
        string[] memory descriptions = new string[](1);
        descriptions[0] = "Milestone 1";
        uint256[] memory funding = new uint256[](1);
        funding[0] = 1 ether;
        uint256[] memory votes = new uint256[](1);
        votes[0] = 3;

        project.createProject("Test Project 2", "Another test project", descriptions, funding, votes);
        uint256 projectId2 = 1;

        portfolio.addPortfolioItem(projectId2, "Non-featured project", tags, "ipfs://media2", false);

        ProjectPortfolio.PortfolioItem[] memory featured = portfolio.getFeaturedItems(user1);
        assertEq(featured.length, 1);
        assertEq(featured[0].projectId, projectId);
        assertEq(featured[0].description, "Featured project");

        vm.stopPrank();
    }

    function testFail_AddPortfolioItemUnregistered() public {
        vm.startPrank(user2); // user2 hasn't created a profile

        string[] memory tags = new string[](1);
        tags[0] = "blockchain";

        portfolio.addPortfolioItem(projectId, "Description", tags, "ipfs://media1", true);
    }

    function testFail_AddDuplicatePortfolioItem() public {
        vm.startPrank(user1);

        string[] memory tags = new string[](1);
        tags[0] = "blockchain";

        portfolio.addPortfolioItem(projectId, "Description", tags, "ipfs://media1", true);

        // Try to add the same project again
        portfolio.addPortfolioItem(projectId, "Another description", tags, "ipfs://media2", false);
    }

    function testFail_RemoveNonexistentItem() public {
        vm.startPrank(user1);
        portfolio.removePortfolioItem(999); // Non-existent project ID
    }
}
