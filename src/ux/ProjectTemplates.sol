// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ProjectCategories} from "./ProjectCategories.sol";

/**
 * @title ProjectTemplates
 * @notice Manages project templates for easy project initialization
 */
contract ProjectTemplates {
    // Enum for template types
    enum TemplateType {
        TechInnovation,
        SocialImpact,
        CreativeArts,
        ResearchAndDevelopment,
        CommunityInitiative,
        Other
    }

    // Struct to represent a project template
    struct Template {
        uint256 id;
        string name;
        TemplateType templateType;
        string description;
        string[] requiredFields;
        uint256[] recommendedCategories;
        bool isActive;
        address creator;
    }

    // Mapping of template ID to Template
    mapping(uint256 => Template) public templates;

    // Counter for template IDs
    uint256 public templateCounter;

    // Reference to ProjectCategories contract
    ProjectCategories public projectCategories;

    // Event for template creation
    event TemplateCreated(uint256 indexed templateId, string name, TemplateType templateType);

    // Event for template usage
    event TemplateUsed(address indexed project, uint256 templateId);

    constructor(address _projectCategoriesAddress) {
        projectCategories = ProjectCategories(_projectCategoriesAddress);
    }

    /**
     * @notice Create a new project template
     * @param _name Name of the template
     * @param _templateType Type of the template
     * @param _description Description of the template
     * @param _requiredFields Fields required for this template
     * @param _recommendedCategories Recommended category IDs
     */
    function createTemplate(
        string memory _name,
        TemplateType _templateType,
        string memory _description,
        string[] memory _requiredFields,
        uint256[] memory _recommendedCategories
    ) public returns (uint256) {
        // Validate recommended categories
        for (uint256 i = 0; i < _recommendedCategories.length; i++) {
            // This will revert if category doesn't exist
            projectCategories.getProjectCategories(address(this));
        }

        templateCounter++;

        templates[templateCounter] = Template({
            id: templateCounter,
            name: _name,
            templateType: _templateType,
            description: _description,
            requiredFields: _requiredFields,
            recommendedCategories: _recommendedCategories,
            isActive: true,
            creator: msg.sender
        });

        emit TemplateCreated(templateCounter, _name, _templateType);
        return templateCounter;
    }

    /**
     * @notice Use a template for a new project
     * @param _templateId ID of the template to use
     * @return Template details
     */
    function useTemplate(uint256 _templateId) public view returns (Template memory) {
        require(templates[_templateId].isActive, "Template is not active");

        return templates[_templateId];
    }

    /**
     * @notice Get templates by type
     * @param _templateType Type of templates to retrieve
     * @return Array of template IDs
     */
    function getTemplatesByType(TemplateType _templateType) public view returns (uint256[] memory) {
        uint256[] memory matchingTemplates = new uint256[](templateCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= templateCounter; i++) {
            if (templates[i].templateType == _templateType && templates[i].isActive) {
                matchingTemplates[count] = i;
                count++;
            }
        }

        // Resize array to actual count
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = matchingTemplates[i];
        }

        return result;
    }
}
