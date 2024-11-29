// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Project.sol";
import "../UserProfile.sol";

/**
 * @title ProjectPortfolio
 * @notice Manages user project portfolios and showcases
 */
contract ProjectPortfolio {
    // Struct to represent a portfolio item
    struct PortfolioItem {
        uint256 projectId;
        string title;
        string description;
        string[] tags;
        string mediaUrl;
        bool featured;
        uint256 addedAt;
    }

    // Struct to represent portfolio metadata
    struct PortfolioMetadata {
        string title;
        string description;
        string[] highlightedSkills;
        bool isPublic;
    }

    // State variables
    Project public projectContract;
    UserProfile public userProfile;

    // Portfolio storage
    mapping(address => PortfolioMetadata) public portfolioMetadata;
    mapping(address => PortfolioItem[]) private portfolioItems;
    mapping(address => mapping(uint256 => bool)) public isProjectInPortfolio;

    // Events
    event PortfolioItemAdded(address indexed user, uint256 indexed projectId);
    event PortfolioItemRemoved(address indexed user, uint256 indexed projectId);
    event PortfolioMetadataUpdated(address indexed user);
    event PortfolioItemUpdated(address indexed user, uint256 indexed projectId);

    // Errors
    error UserNotRegistered();
    error ProjectNotFound();
    error ProjectAlreadyInPortfolio();
    error ProjectNotInPortfolio();
    error Unauthorized();

    constructor(address payable _projectAddress, address _userProfileAddress) {
        projectContract = Project(_projectAddress);
        userProfile = UserProfile(_userProfileAddress);
    }

    /// @notice Add a project to user's portfolio
    /// @param _projectId ID of the project
    /// @param _description Custom description for the portfolio
    /// @param _tags Tags for the portfolio item
    /// @param _mediaUrl URL to media showcasing the project
    /// @param _featured Whether this is a featured project
    function addPortfolioItem(
        uint256 _projectId,
        string calldata _description,
        string[] calldata _tags,
        string calldata _mediaUrl,
        bool _featured
    ) external {
        if (!userProfile.hasProfile(msg.sender)) revert UserNotRegistered();
        if (isProjectInPortfolio[msg.sender][_projectId]) revert ProjectAlreadyInPortfolio();

        // Create portfolio item with project ID
        PortfolioItem memory item = PortfolioItem({
            projectId: _projectId,
            title: "Project", // Default title, can be updated later
            description: _description,
            tags: _tags,
            mediaUrl: _mediaUrl,
            featured: _featured,
            addedAt: block.timestamp
        });

        portfolioItems[msg.sender].push(item);
        isProjectInPortfolio[msg.sender][_projectId] = true;

        emit PortfolioItemAdded(msg.sender, _projectId);
    }

    /// @notice Remove a project from user's portfolio
    /// @param _projectId ID of the project to remove
    function removePortfolioItem(uint256 _projectId) external {
        if (!isProjectInPortfolio[msg.sender][_projectId]) revert ProjectNotInPortfolio();

        uint256 itemIndex;
        bool found;

        for (uint256 i = 0; i < portfolioItems[msg.sender].length; i++) {
            if (portfolioItems[msg.sender][i].projectId == _projectId) {
                itemIndex = i;
                found = true;
                break;
            }
        }

        require(found, "Project not found in portfolio");

        // Remove item by swapping with last element and popping
        portfolioItems[msg.sender][itemIndex] = portfolioItems[msg.sender][portfolioItems[msg.sender].length - 1];
        portfolioItems[msg.sender].pop();
        isProjectInPortfolio[msg.sender][_projectId] = false;

        emit PortfolioItemRemoved(msg.sender, _projectId);
    }

    /// @notice Update portfolio metadata
    /// @param _title Portfolio title
    /// @param _description Portfolio description
    /// @param _highlightedSkills Array of highlighted skills
    /// @param _isPublic Whether the portfolio is public
    function updatePortfolioMetadata(
        string calldata _title,
        string calldata _description,
        string[] calldata _highlightedSkills,
        bool _isPublic
    ) external {
        if (!userProfile.hasProfile(msg.sender)) revert UserNotRegistered();

        portfolioMetadata[msg.sender] = PortfolioMetadata({
            title: _title,
            description: _description,
            highlightedSkills: _highlightedSkills,
            isPublic: _isPublic
        });

        emit PortfolioMetadataUpdated(msg.sender);
    }

    /// @notice Update a portfolio item
    /// @param _projectId ID of the project to update
    /// @param _description New description
    /// @param _tags New tags
    /// @param _mediaUrl New media URL
    /// @param _featured New featured status
    function updatePortfolioItem(
        uint256 _projectId,
        string calldata _description,
        string[] calldata _tags,
        string calldata _mediaUrl,
        bool _featured
    ) external {
        if (!isProjectInPortfolio[msg.sender][_projectId]) revert ProjectNotInPortfolio();

        for (uint256 i = 0; i < portfolioItems[msg.sender].length; i++) {
            if (portfolioItems[msg.sender][i].projectId == _projectId) {
                portfolioItems[msg.sender][i].description = _description;
                portfolioItems[msg.sender][i].tags = _tags;
                portfolioItems[msg.sender][i].mediaUrl = _mediaUrl;
                portfolioItems[msg.sender][i].featured = _featured;
                break;
            }
        }

        emit PortfolioItemUpdated(msg.sender, _projectId);
    }

    /// @notice Get all portfolio items for a user
    /// @param _user Address of the user
    /// @return Array of portfolio items
    function getPortfolioItems(address _user) external view returns (PortfolioItem[] memory) {
        if (!portfolioMetadata[_user].isPublic && _user != msg.sender) revert Unauthorized();
        return portfolioItems[_user];
    }

    /// @notice Get featured portfolio items for a user
    /// @param _user Address of the user
    /// @return Array of featured portfolio items
    function getFeaturedItems(address _user) external view returns (PortfolioItem[] memory) {
        if (!portfolioMetadata[_user].isPublic && _user != msg.sender) revert Unauthorized();

        // Count featured items
        uint256 featuredCount = 0;
        for (uint256 i = 0; i < portfolioItems[_user].length; i++) {
            if (portfolioItems[_user][i].featured) {
                featuredCount++;
            }
        }

        // Create array of featured items
        PortfolioItem[] memory featured = new PortfolioItem[](featuredCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < portfolioItems[_user].length; i++) {
            if (portfolioItems[_user][i].featured) {
                featured[currentIndex] = portfolioItems[_user][i];
                currentIndex++;
            }
        }

        return featured;
    }

    /// @notice Get portfolio metadata for a user
    /// @param _user Address of the user
    /// @return title Portfolio title
    /// @return description Portfolio description
    /// @return highlightedSkills Array of highlighted skills
    /// @return isPublic Whether the portfolio is public
    function getPortfolioMetadata(address _user)
        external
        view
        returns (string memory title, string memory description, string[] memory highlightedSkills, bool isPublic)
    {
        PortfolioMetadata storage metadata = portfolioMetadata[_user];
        return (metadata.title, metadata.description, metadata.highlightedSkills, metadata.isPublic);
    }
}
