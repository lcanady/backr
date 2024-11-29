// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./UserProfile.sol";
import "./SecurityControls.sol";

/// @title Project Contract for Backr Platform
/// @notice Manages project creation, funding, and milestone tracking
contract Project is SecurityControls {
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

    // Operation identifiers for rate limiting and multi-sig
    bytes32 public constant CREATE_PROJECT_OPERATION = keccak256("CREATE_PROJECT");
    bytes32 public constant LARGE_FUNDING_OPERATION = keccak256("LARGE_FUNDING");
    bytes32 public constant MILESTONE_COMPLETION_OPERATION = keccak256("MILESTONE_COMPLETION");

    // Funding thresholds
    uint256 public constant LARGE_FUNDING_THRESHOLD = 10 ether;

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

    constructor(address _userProfileAddress) SecurityControls() {
        userProfile = UserProfile(_userProfileAddress);

        // Grant the deployer the DEFAULT_ADMIN_ROLE
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Configure rate limits
        _configureRateLimit(CREATE_PROJECT_OPERATION, 1, 24 hours); // 1 project per 24 hours
        _configureRateLimit(MILESTONE_COMPLETION_OPERATION, 10, 1 days); // 10 milestone completions per day

        // Initialize emergency settings
        emergencyConfig.cooldownPeriod = 12 hours;

        // Setup default multi-sig configuration for large funding
        address[] memory defaultApprovers = new address[](1);
        defaultApprovers[0] = msg.sender;
        configureMultiSig(LARGE_FUNDING_OPERATION, 1, defaultApprovers);
    }

    /// @notice Creates a new project with initial milestones
    /// @param _title Project title
    /// @param _description Project description
    /// @param _milestoneDescriptions Array of milestone descriptions
    /// @param _milestoneFunding Array of funding requirements for each milestone
    /// @param _milestoneVotesRequired Array of required votes for each milestone
    function createProject(
        string calldata _title,
        string calldata _description,
        string[] calldata _milestoneDescriptions,
        uint256[] calldata _milestoneFunding,
        uint256[] calldata _milestoneVotesRequired
    ) external whenNotPaused rateLimitGuard(CREATE_PROJECT_OPERATION) {
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

    /// @notice Contributes funds to a project
    function contributeToProject(uint256 _projectId)
        external
        payable
        whenNotPaused
        whenCircuitBreakerOff
        nonReentrant
    {
        if (!projects[_projectId].isActive) revert ProjectNotFound();
        if (msg.value == 0) revert InsufficientFunds();

        // For large funding amounts, require multi-sig approval
        if (msg.value >= LARGE_FUNDING_THRESHOLD) {
            bytes32 txHash = keccak256(abi.encodePacked(_projectId, msg.sender, msg.value, block.timestamp));
            MultiSigConfig storage config = multiSigConfigs[LARGE_FUNDING_OPERATION];
            require(config.executed[txHash], "Requires multi-sig approval");
        }

        ProjectDetails storage project = projects[_projectId];
        project.currentFunding += msg.value;

        emit FundsContributed(_projectId, msg.sender, msg.value);
    }

    /// @notice Vote for milestone completion
    /// @param _projectId ID of the project
    /// @param _milestoneId ID of the milestone
    function voteMilestone(uint256 _projectId, uint256 _milestoneId) external whenNotPaused whenCircuitBreakerOff {
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
        whenNotPaused
        whenCircuitBreakerOff
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
        whenNotPaused
        whenCircuitBreakerOff
        returns (bool)
    {
        return projects[_projectId].milestones[_milestoneId].hasVoted[_voter];
    }

    /// @notice Emergency withdrawal of funds
    function emergencyWithdraw(uint256 _projectId) external onlyRole(EMERGENCY_ROLE) whenPaused {
        ProjectDetails storage project = projects[_projectId];
        if (!project.isActive) revert ProjectNotFound();

        uint256 amount = project.currentFunding;
        project.currentFunding = 0;
        project.isActive = false;

        (bool success,) = project.creator.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /// @notice Receive function to accept ETH payments
    receive() external payable {}
}
