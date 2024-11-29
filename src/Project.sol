// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./UserProfile.sol";

/// @title Project Contract for Backr Platform
/// @notice Manages project creation, funding, and milestone tracking
contract Project {
    // Structs
    struct Milestone {
        string description;
        uint256 fundingRequired;
        uint256 votesRequired;
        uint256 votesReceived;
        bool isCompleted;
        mapping(address => bool) hasVoted;
    }

    struct ProjectDetails {
        address creator;
        string title;
        string description;
        uint256 totalFundingGoal;
        uint256 currentFunding;
        uint256 milestoneCount;
        bool isActive;
        uint256 createdAt;
        mapping(uint256 => Milestone) milestones;
    }

    // State variables
    UserProfile public userProfile;
    mapping(uint256 => ProjectDetails) public projects;
    uint256 public totalProjects;

    // Events
    event ProjectCreated(uint256 indexed projectId, address indexed creator, string title);
    event MilestoneAdded(uint256 indexed projectId, uint256 milestoneId, string description);
    event FundsContributed(uint256 indexed projectId, address indexed contributor, uint256 amount);
    event MilestoneCompleted(uint256 indexed projectId, uint256 milestoneId);
    event FundsReleased(uint256 indexed projectId, uint256 milestoneId, uint256 amount);

    // Errors
    error UserNotRegistered();
    error InvalidProjectParameters();
    error ProjectNotFound();
    error InsufficientFunds();
    error MilestoneNotFound();
    error AlreadyVoted();
    error MilestoneAlreadyCompleted();
    error InsufficientVotes();

    constructor(address _userProfileAddress) {
        userProfile = UserProfile(_userProfileAddress);
    }

    /// @notice Creates a new project with initial milestones
    /// @param _title Project title
    /// @param _description Project description
    /// @param _milestoneDescriptions Array of milestone descriptions
    /// @param _milestoneFunding Array of funding requirements for each milestone
    /// @param _milestoneVotesRequired Array of required votes for each milestone
    function createProject(
        string memory _title,
        string memory _description,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestoneFunding,
        uint256[] memory _milestoneVotesRequired
    ) external {
        if (!userProfile.hasProfile(msg.sender)) revert UserNotRegistered();
        if (bytes(_title).length == 0 || _milestoneDescriptions.length == 0) revert InvalidProjectParameters();
        if (
            _milestoneDescriptions.length != _milestoneFunding.length
                || _milestoneFunding.length != _milestoneVotesRequired.length
        ) revert InvalidProjectParameters();

        uint256 projectId = totalProjects++;
        ProjectDetails storage project = projects[projectId];
        project.creator = msg.sender;
        project.title = _title;
        project.description = _description;
        project.isActive = true;
        project.createdAt = block.timestamp;

        uint256 totalFunding = 0;
        for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
            Milestone storage milestone = project.milestones[i];
            milestone.description = _milestoneDescriptions[i];
            milestone.fundingRequired = _milestoneFunding[i];
            milestone.votesRequired = _milestoneVotesRequired[i];
            totalFunding += _milestoneFunding[i];
        }

        project.totalFundingGoal = totalFunding;
        project.milestoneCount = _milestoneDescriptions.length;

        emit ProjectCreated(projectId, msg.sender, _title);
        for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
            emit MilestoneAdded(projectId, i, _milestoneDescriptions[i]);
        }
    }

    /// @notice Contribute funds to a project
    /// @param _projectId ID of the project
    function contributeToProject(uint256 _projectId) external payable {
        if (!projects[_projectId].isActive) revert ProjectNotFound();
        if (msg.value == 0) revert InsufficientFunds();

        ProjectDetails storage project = projects[_projectId];
        project.currentFunding += msg.value;

        emit FundsContributed(_projectId, msg.sender, msg.value);
    }

    /// @notice Vote for milestone completion
    /// @param _projectId ID of the project
    /// @param _milestoneId ID of the milestone
    function voteMilestone(uint256 _projectId, uint256 _milestoneId) external {
        ProjectDetails storage project = projects[_projectId];
        if (!project.isActive) revert ProjectNotFound();
        if (_milestoneId >= project.milestoneCount) revert MilestoneNotFound();

        Milestone storage milestone = project.milestones[_milestoneId];
        if (milestone.isCompleted) revert MilestoneAlreadyCompleted();
        if (milestone.hasVoted[msg.sender]) revert AlreadyVoted();

        milestone.hasVoted[msg.sender] = true;
        milestone.votesReceived++;

        if (milestone.votesReceived >= milestone.votesRequired) {
            milestone.isCompleted = true;
            _releaseFunds(_projectId, _milestoneId);
            emit MilestoneCompleted(_projectId, _milestoneId);
        }
    }

    /// @notice Internal function to release funds for completed milestone
    /// @param _projectId ID of the project
    /// @param _milestoneId ID of the milestone
    function _releaseFunds(uint256 _projectId, uint256 _milestoneId) internal {
        ProjectDetails storage project = projects[_projectId];
        Milestone storage milestone = project.milestones[_milestoneId];

        uint256 amount = milestone.fundingRequired;
        if (address(this).balance < amount) revert InsufficientFunds();

        (bool sent,) = project.creator.call{value: amount}("");
        require(sent, "Failed to send funds");

        emit FundsReleased(_projectId, _milestoneId, amount);
    }

    /// @notice Get milestone details
    /// @param _projectId ID of the project
    /// @param _milestoneId ID of the milestone
    function getMilestone(uint256 _projectId, uint256 _milestoneId)
        external
        view
        returns (
            string memory description,
            uint256 fundingRequired,
            uint256 votesRequired,
            uint256 votesReceived,
            bool isCompleted
        )
    {
        if (!projects[_projectId].isActive) revert ProjectNotFound();
        if (_milestoneId >= projects[_projectId].milestoneCount) revert MilestoneNotFound();

        Milestone storage milestone = projects[_projectId].milestones[_milestoneId];
        return (
            milestone.description,
            milestone.fundingRequired,
            milestone.votesRequired,
            milestone.votesReceived,
            milestone.isCompleted
        );
    }

    /// @notice Check if an address has voted for a milestone
    /// @param _projectId ID of the project
    /// @param _milestoneId ID of the milestone
    /// @param _voter Address to check
    function hasVotedForMilestone(uint256 _projectId, uint256 _milestoneId, address _voter)
        external
        view
        returns (bool)
    {
        return projects[_projectId].milestones[_milestoneId].hasVoted[_voter];
    }

    /// @notice Receive function to accept ETH payments
    receive() external payable {}
}
