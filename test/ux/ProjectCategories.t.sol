// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ProjectCategories} from "../../src/ux/ProjectCategories.sol";

contract ProjectCategoriesTest is Test {
    ProjectCategories public projectCategories;
    address public testUser;

    function setUp() public {
        projectCategories = new ProjectCategories();
        testUser = makeAddr("testUser");
    }

    function testCreateCategory() public {
        uint256 categoryId = projectCategories.createCategory(
            "Tech Innovation", ProjectCategories.ProjectDomain.Technology, "Innovative technology projects"
        );

        (
            uint256 id,
            string memory name,
            ProjectCategories.ProjectDomain domain,
            string memory description,
            bool isActive
        ) = projectCategories.categories(categoryId);

        assertEq(id, categoryId);
        assertEq(name, "Tech Innovation");
        assertEq(uint256(domain), uint256(ProjectCategories.ProjectDomain.Technology));
        assertEq(description, "Innovative technology projects");
        assertTrue(isActive);
    }

    function testCategorizeProject() public {
        // Create some categories
        uint256 techCategoryId = projectCategories.createCategory(
            "Tech Innovation", ProjectCategories.ProjectDomain.Technology, "Innovative technology projects"
        );
        uint256 socialCategoryId = projectCategories.createCategory(
            "Social Impact", ProjectCategories.ProjectDomain.SocialImpact, "Projects with social good"
        );

        // Prepare category IDs
        uint256[] memory categoryIds = new uint256[](2);
        categoryIds[0] = techCategoryId;
        categoryIds[1] = socialCategoryId;

        // Categorize project
        vm.prank(testUser);
        projectCategories.categorizeProject(testUser, categoryIds);

        // Verify categorization
        uint256[] memory retrievedCategories = projectCategories.getProjectCategories(testUser);

        assertEq(retrievedCategories.length, 2);
        assertEq(retrievedCategories[0], techCategoryId);
        assertEq(retrievedCategories[1], socialCategoryId);
    }

    function testCannotCategorizeWithInvalidCategory() public {
        uint256[] memory invalidCategories = new uint256[](1);
        invalidCategories[0] = 999; // Non-existent category

        vm.expectRevert("Invalid or inactive category");
        projectCategories.categorizeProject(testUser, invalidCategories);
    }
}
