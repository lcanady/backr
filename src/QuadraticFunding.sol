// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Project.sol";

/// @title QuadraticFunding Contract for Backr Platform
/// @notice Manages quadratic funding pool and matching calculations
contract QuadraticFunding {
    // Structs
    struct Round {
        uint256 startTime;
        uint256 endTime;
        uint256 matchingPool;
        uint256 totalContributions;
        bool isFinalized;
        mapping(uint256 => uint256) projectContributions; // projectId => total contributions
        mapping(uint256 => mapping(address => uint256)) contributions; // projectId => contributor => amount
        mapping(uint256 => uint256) matchingAmount; // projectId => matching amount
    }

    // State variables
    Project public projectContract;
    mapping(uint256 => Round) public rounds;
    uint256 public currentRound;
    uint256 public constant ROUND_DURATION = 14 days;

    // Events
    event RoundStarted(uint256 indexed roundId, uint256 matchingPool);
    event ContributionAdded(uint256 indexed roundId, uint256 indexed projectId, address indexed contributor, uint256 amount);
    event RoundFinalized(uint256 indexed roundId, uint256 totalMatching);
    event MatchingFundsDistributed(uint256 indexed roundId, uint256 indexed projectId, uint256 amount);

    // Errors
    error RoundNotActive();
    error RoundAlreadyActive();
    error InsufficientContribution();
    error RoundNotEnded();
    error RoundAlreadyFinalized();
    error NoContributions();
    error MatchingPoolEmpty();

    constructor(address payable _projectContract) {
        projectContract = Project(_projectContract);
    }

    /// @notice Start a new funding round
    function startRound() external payable {
        if (isRoundActive()) revert RoundAlreadyActive();
        if (msg.value == 0) revert MatchingPoolEmpty();

        uint256 roundId = currentRound++;
        Round storage round = rounds[roundId];
        round.startTime = block.timestamp;
        round.endTime = block.timestamp + ROUND_DURATION;
        round.matchingPool = msg.value;

        emit RoundStarted(roundId, msg.value);
    }

    /// @notice Contribute to a project in the current round
    /// @param _projectId ID of the project to contribute to
    function contribute(uint256 _projectId) external payable {
        if (!isRoundActive()) revert RoundNotActive();
        if (msg.value == 0) revert InsufficientContribution();

        Round storage round = rounds[currentRound - 1];
        round.contributions[_projectId][msg.sender] += msg.value;
        round.projectContributions[_projectId] += msg.value;
        round.totalContributions += msg.value;

        // Forward the contribution to the project contract
        (bool sent,) = address(projectContract).call{value: msg.value}("");
        require(sent, "Failed to forward contribution");

        emit ContributionAdded(currentRound - 1, _projectId, msg.sender, msg.value);
    }

    /// @notice Finalize the current round and calculate matching amounts
    function finalizeRound() external {
        uint256 roundId = currentRound - 1;
        Round storage round = rounds[roundId];

        if (block.timestamp <= round.endTime) revert RoundNotEnded();
        if (round.isFinalized) revert RoundAlreadyFinalized();
        if (round.totalContributions == 0) revert NoContributions();

        uint256 totalSquareRoots;
        uint256[] memory projectIds = _getProjectsInRound(roundId);

        // Calculate sum of square roots of contributions
        for (uint256 i = 0; i < projectIds.length; i++) {
            uint256 projectId = projectIds[i];
            uint256 sqrtContributions = _sqrt(round.projectContributions[projectId]);
            totalSquareRoots += sqrtContributions;
        }

        // Calculate and distribute matching funds
        for (uint256 i = 0; i < projectIds.length; i++) {
            uint256 projectId = projectIds[i];
            uint256 sqrtContributions = _sqrt(round.projectContributions[projectId]);
            uint256 matchingAmount;
            
            if (i == projectIds.length - 1) {
                // Last project gets remaining funds to avoid rounding issues
                matchingAmount = round.matchingPool - round.matchingAmount[projectIds[0]];
            } else {
                matchingAmount = (round.matchingPool * sqrtContributions) / totalSquareRoots;
            }
            
            round.matchingAmount[projectId] = matchingAmount;
            
            // Transfer matching funds to project contract
            (bool sent,) = address(projectContract).call{value: matchingAmount}("");
            require(sent, "Failed to send matching funds");
            
            emit MatchingFundsDistributed(roundId, projectId, matchingAmount);
        }

        round.isFinalized = true;
        emit RoundFinalized(roundId, round.matchingPool);
    }

    /// @notice Check if there's currently an active funding round
    function isRoundActive() public view returns (bool) {
        if (currentRound == 0) return false;
        Round storage round = rounds[currentRound - 1];
        return block.timestamp >= round.startTime && 
               block.timestamp <= round.endTime && 
               !round.isFinalized;
    }

    /// @notice Get the total contribution amount for a project in a round
    /// @param _roundId Round ID
    /// @param _projectId Project ID
    function getProjectContributions(uint256 _roundId, uint256 _projectId) external view returns (uint256) {
        return rounds[_roundId].projectContributions[_projectId];
    }

    /// @notice Get the matching amount for a project in a round
    /// @param _roundId Round ID
    /// @param _projectId Project ID
    function getMatchingAmount(uint256 _roundId, uint256 _projectId) external view returns (uint256) {
        return rounds[_roundId].matchingAmount[_projectId];
    }

    /// @notice Get contribution amount from a specific contributor for a project
    /// @param _roundId Round ID
    /// @param _projectId Project ID
    /// @param _contributor Contributor address
    function getContribution(uint256 _roundId, uint256 _projectId, address _contributor) external view returns (uint256) {
        return rounds[_roundId].contributions[_projectId][_contributor];
    }

    /// @notice Helper function to calculate square root
    /// @param x Number to calculate square root of
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        return y;
    }

    /// @notice Helper function to get all projects that received contributions in a round
    /// @param _roundId Round ID
    function _getProjectsInRound(uint256 _roundId) internal view returns (uint256[] memory) {
        Round storage round = rounds[_roundId];
        uint256 count = 0;
        
        // First pass: count projects
        for (uint256 i = 0; i < 1000; i++) { // Arbitrary limit for gas considerations
            if (round.projectContributions[i] > 0) {
                count++;
            }
        }
        
        // Second pass: collect project IDs
        uint256[] memory projects = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < 1000; i++) {
            if (round.projectContributions[i] > 0) {
                projects[index] = i;
                index++;
            }
        }
        
        return projects;
    }
}
