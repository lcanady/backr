// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DisputeResolution
 * @notice Provides a structured system for resolving project-related disputes
 */
contract DisputeResolution {
    // Enum for dispute categories
    enum DisputeCategory {
        Funding,
        MilestoneCompletion,
        Collaboration,
        Deliverables,
        Other
    }

    // Enum for dispute status
    enum DisputeStatus {
        Initiated,
        UnderReview,
        Mediation,
        Resolved,
        Closed
    }

    // Struct to represent a dispute
    struct Dispute {
        uint256 id;
        address project;
        address initiator;
        address respondent;
        DisputeCategory category;
        string description;
        DisputeStatus status;
        uint256 createdAt;
        uint256 resolvedAt;
        address mediator;
        string resolution;
    }

    // Mapping of dispute ID to Dispute
    mapping(uint256 => Dispute) public disputes;

    // Counter for dispute IDs
    uint256 public disputeCounter;

    // Mapping to track active disputes per project
    mapping(address => uint256[]) public projectDisputes;

    // Mapping of approved mediators
    mapping(address => bool) public approvedMediators;

    // Events
    event DisputeInitiated(
        uint256 indexed disputeId, address indexed project, address initiator, DisputeCategory category
    );

    event DisputeStatusChanged(uint256 indexed disputeId, DisputeStatus newStatus);

    event DisputeResolved(uint256 indexed disputeId, string resolution);

    // Modifier to restrict actions to approved mediators
    modifier onlyApprovedMediator() {
        require(approvedMediators[msg.sender], "Not an approved mediator");
        _;
    }

    /**
     * @notice Add an approved mediator
     * @param _mediator Address of the mediator
     */
    function addMediator(address _mediator) public {
        approvedMediators[_mediator] = true;
    }

    /**
     * @notice Initiate a new dispute
     * @param _project Project address
     * @param _respondent Address of the respondent
     * @param _category Dispute category
     * @param _description Detailed description of the dispute
     */
    function initiateDispute(
        address _project,
        address _respondent,
        DisputeCategory _category,
        string memory _description
    ) public returns (uint256) {
        disputeCounter++;

        disputes[disputeCounter] = Dispute({
            id: disputeCounter,
            project: _project,
            initiator: msg.sender,
            respondent: _respondent,
            category: _category,
            description: _description,
            status: DisputeStatus.Initiated,
            createdAt: block.timestamp,
            resolvedAt: 0,
            mediator: address(0),
            resolution: ""
        });

        projectDisputes[_project].push(disputeCounter);

        emit DisputeInitiated(disputeCounter, _project, msg.sender, _category);

        return disputeCounter;
    }

    /**
     * @notice Update dispute status
     * @param _disputeId ID of the dispute
     * @param _newStatus New status for the dispute
     */
    function updateDisputeStatus(uint256 _disputeId, DisputeStatus _newStatus) public onlyApprovedMediator {
        disputes[_disputeId].status = _newStatus;

        emit DisputeStatusChanged(_disputeId, _newStatus);
    }

    /**
     * @notice Resolve a dispute
     * @param _disputeId ID of the dispute
     * @param _resolution Resolution details
     */
    function resolveDispute(uint256 _disputeId, string memory _resolution) public onlyApprovedMediator {
        Dispute storage dispute = disputes[_disputeId];

        dispute.status = DisputeStatus.Resolved;
        dispute.resolution = _resolution;
        dispute.resolvedAt = block.timestamp;

        emit DisputeResolved(_disputeId, _resolution);
    }

    /**
     * @notice Get disputes for a project
     * @param _project Project address
     * @return Array of dispute IDs
     */
    function getProjectDisputes(address _project) public view returns (uint256[] memory) {
        return projectDisputes[_project];
    }
}
