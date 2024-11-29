// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ProjectCategories
 * @notice Manages project categories and tags for discovery
 */
contract ProjectCategories {
    // Enum for predefined project domains
    enum ProjectDomain {
        Technology,
        SocialImpact,
        CreativeArts,
        Education,
        Environment,
        Healthcare,
        Other
    }

    // Struct to represent a project category
    struct Category {
        uint256 id;
        string name;
        ProjectDomain domain;
        string description;
        bool isActive;
    }

    // Mapping of category ID to Category
    mapping(uint256 => Category) public categories;

    // Counter for category IDs
    uint256 public categoryCounter;

    // Mapping of project address to its categories/tags
    mapping(address => uint256[]) public projectCategories;

    // Event for category creation
    event CategoryCreated(uint256 indexed categoryId, string name, ProjectDomain domain);

    // Event for project categorization
    event ProjectCategorized(address indexed project, uint256[] categoryIds);

    /**
     * @notice Create a new project category
     * @param _name Name of the category
     * @param _domain Domain of the category
     * @param _description Description of the category
     */
    function createCategory(string memory _name, ProjectDomain _domain, string memory _description)
        public
        returns (uint256)
    {
        categoryCounter++;

        categories[categoryCounter] =
            Category({id: categoryCounter, name: _name, domain: _domain, description: _description, isActive: true});

        emit CategoryCreated(categoryCounter, _name, _domain);
        return categoryCounter;
    }

    /**
     * @notice Assign categories to a project
     * @param _project Address of the project
     * @param _categoryIds Array of category IDs to assign
     */
    function categorizeProject(address _project, uint256[] memory _categoryIds) public {
        // Validate category IDs exist
        for (uint256 i = 0; i < _categoryIds.length; i++) {
            require(categories[_categoryIds[i]].isActive, "Invalid or inactive category");
        }

        projectCategories[_project] = _categoryIds;

        emit ProjectCategorized(_project, _categoryIds);
    }

    /**
     * @notice Get categories for a specific project
     * @param _project Address of the project
     * @return Array of category IDs
     */
    function getProjectCategories(address _project) public view returns (uint256[] memory) {
        return projectCategories[_project];
    }
}
