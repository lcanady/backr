// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Governance
 * @dev Contract for managing platform governance through a DAO structure
 */
contract Governance is Ownable {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    IERC20 public platformToken;
    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant PROPOSAL_THRESHOLD = 100 * 10**18; // 100 tokens needed to create proposal
    
    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 startTime,
        uint256 endTime
    );
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId);

    constructor(address _platformToken) {
        platformToken = IERC20(_platformToken);
    }

    /**
     * @dev Create a new proposal
     * @param description Description of the proposal
     */
    function createProposal(string memory description) external {
        require(
            platformToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD,
            "Insufficient tokens to create proposal"
        );

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_PERIOD;

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.description = description;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            description,
            startTime,
            endTime
        );
    }

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId ID of the proposal
     * @param support True for support, false for against
     */
    function castVote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        uint256 votes = platformToken.balanceOf(msg.sender);
        require(votes > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    /**
     * @dev Execute a proposal after voting period ends
     * @param proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
        
        // Implementation of proposal execution would go here
        // This could involve calling other contracts or updating platform parameters
    }

    /**
     * @dev Get the current state of a proposal
     * @param proposalId ID of the proposal
     * @return forVotes Number of votes in support
     * @return againstVotes Number of votes against
     * @return startTime Start time of voting period
     * @return endTime End time of voting period
     * @return executed Whether the proposal has been executed
     */
    function getProposal(uint256 proposalId) external view returns (
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.forVotes,
            proposal.againstVotes,
            proposal.startTime,
            proposal.endTime,
            proposal.executed
        );
    }
}
