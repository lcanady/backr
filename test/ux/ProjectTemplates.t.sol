// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ProjectCategories} from "../../src/ux/ProjectCategories.sol";
import {ProjectTemplates} from "../../src/ux/ProjectTemplates.sol";

contract ProjectTemplatesTest is Test {
    ProjectCategories public projectCategories;
    ProjectTemplates public projectTemplates;
    address public testUser;

    function setUp() public {
        projectCategories = new ProjectCategories();
        projectTemplates = new ProjectTemplates(address(projectCategories));
        testUser = makeAddr("testUser");
    }

    function testCreateTemplate() public {
        // Create some categories first
        uint256 techCategoryId = projectCategories.createCategory(
            "Tech Innovation", ProjectCategories.ProjectDomain.Technology, "Innovative technology projects"
        );

        // Prepare required fields
        string[] memory requiredFields = new string[](2);
        requiredFields[0] = "Project Name";
        requiredFields[1] = "Project Description";

        // Prepare recommended categories
        uint256[] memory recommendedCategories = new uint256[](1);
        recommendedCategories[0] = techCategoryId;

        // Create template
        vm.prank(testUser);
        uint256 templateId = projectTemplates.createTemplate(
            "Tech Startup Template",
            ProjectTemplates.TemplateType.TechInnovation,
            "Template for tech startup projects",
            requiredFields,
            recommendedCategories
        );

        // Retrieve and verify template
        ProjectTemplates.Template memory template = projectTemplates.useTemplate(templateId);

        assertEq(template.id, templateId);
        assertEq(template.name, "Tech Startup Template");
        assertEq(uint256(template.templateType), uint256(ProjectTemplates.TemplateType.TechInnovation));
        assertEq(template.description, "Template for tech startup projects");
        assertEq(template.requiredFields.length, 2);
        assertEq(template.requiredFields[0], "Project Name");
        assertEq(template.recommendedCategories[0], techCategoryId);
        assertTrue(template.isActive);
        assertEq(template.creator, testUser);
    }

    function testGetTemplatesByType() public {
        // Create multiple templates of different types
        vm.prank(testUser);
        projectTemplates.createTemplate(
            "Tech Startup Template 1",
            ProjectTemplates.TemplateType.TechInnovation,
            "First tech startup template",
            new string[](0),
            new uint256[](0)
        );

        vm.prank(testUser);
        projectTemplates.createTemplate(
            "Tech Startup Template 2",
            ProjectTemplates.TemplateType.TechInnovation,
            "Second tech startup template",
            new string[](0),
            new uint256[](0)
        );

        vm.prank(testUser);
        projectTemplates.createTemplate(
            "Social Impact Template",
            ProjectTemplates.TemplateType.SocialImpact,
            "Social impact project template",
            new string[](0),
            new uint256[](0)
        );

        // Get templates by type
        uint256[] memory techTemplates =
            projectTemplates.getTemplatesByType(ProjectTemplates.TemplateType.TechInnovation);
        uint256[] memory socialTemplates =
            projectTemplates.getTemplatesByType(ProjectTemplates.TemplateType.SocialImpact);

        // Verify results
        assertEq(techTemplates.length, 2);
        assertEq(socialTemplates.length, 1);
    }

    function testUseTemplate() public {
        // Create a template
        uint256 templateId = projectTemplates.createTemplate(
            "Tech Startup Template",
            ProjectTemplates.TemplateType.TechInnovation,
            "Template for tech startup projects",
            new string[](2),
            new uint256[](0)
        );

        // Use the template
        ProjectTemplates.Template memory usedTemplate = projectTemplates.useTemplate(templateId);

        // Verify template details
        assertEq(usedTemplate.name, "Tech Startup Template");
        assertEq(uint256(usedTemplate.templateType), uint256(ProjectTemplates.TemplateType.TechInnovation));
    }
}
