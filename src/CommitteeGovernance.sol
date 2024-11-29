// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Governance.sol";

/**
 * @title CommitteeGovernance
 * @dev Manages specialized committees with their own voting domains
 */
contract CommitteeGovernance is AccessControl {
    bytes32 public constant COMMITTEE_ADMIN_ROLE = keccak256("COMMITTEE_ADMIN_ROLE");

    struct Committee {
        string name;
        string description;
        uint256 votingPowerMultiplier; // Multiplier for committee members' voting power (in basis points)
        bool active;
        mapping(address => bool) members;
        mapping(bytes4 => bool) allowedFunctions; // Function selectors this committee can propose
    }

    // Mapping of committee ID to Committee
    mapping(uint256 => Committee) public committees;
    uint256 public committeeCount;

    // Governance contract reference
    Governance public governance;

    event CommitteeCreated(uint256 indexed committeeId, string name);
    event MemberAdded(uint256 indexed committeeId, address indexed member);
    event MemberRemoved(uint256 indexed committeeId, address indexed member);
    event FunctionAllowed(uint256 indexed committeeId, bytes4 indexed functionSelector);
    event FunctionDisallowed(uint256 indexed committeeId, bytes4 indexed functionSelector);

    constructor(address _governanceAddress) {
        governance = Governance(_governanceAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(COMMITTEE_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Create a new committee
     * @param name Name of the committee
     * @param description Description of the committee's purpose
     * @param votingPowerMultiplier Voting power multiplier for committee members
     */
    function createCommittee(string memory name, string memory description, uint256 votingPowerMultiplier)
        external
        onlyRole(COMMITTEE_ADMIN_ROLE)
    {
        require(votingPowerMultiplier <= 10000, "Multiplier cannot exceed 100x");

        uint256 committeeId = committeeCount++;
        Committee storage committee = committees[committeeId];
        committee.name = name;
        committee.description = description;
        committee.votingPowerMultiplier = votingPowerMultiplier;
        committee.active = true;

        emit CommitteeCreated(committeeId, name);
    }

    /**
     * @dev Add a member to a committee
     * @param committeeId ID of the committee
     * @param member Address of the new member
     */
    function addMember(uint256 committeeId, address member) external onlyRole(COMMITTEE_ADMIN_ROLE) {
        require(committeeId < committeeCount, "Committee does not exist");
        require(!committees[committeeId].members[member], "Already a member");

        committees[committeeId].members[member] = true;
        emit MemberAdded(committeeId, member);
    }

    /**
     * @dev Remove a member from a committee
     * @param committeeId ID of the committee
     * @param member Address of the member to remove
     */
    function removeMember(uint256 committeeId, address member) external onlyRole(COMMITTEE_ADMIN_ROLE) {
        require(committeeId < committeeCount, "Committee does not exist");
        require(committees[committeeId].members[member], "Not a member");

        committees[committeeId].members[member] = false;
        emit MemberRemoved(committeeId, member);
    }

    /**
     * @dev Allow a function to be proposed by a committee
     * @param committeeId ID of the committee
     * @param functionSelector Function selector to allow
     */
    function allowFunction(uint256 committeeId, bytes4 functionSelector) external onlyRole(COMMITTEE_ADMIN_ROLE) {
        require(committeeId < committeeCount, "Committee does not exist");
        committees[committeeId].allowedFunctions[functionSelector] = true;
        emit FunctionAllowed(committeeId, functionSelector);
    }

    /**
     * @dev Check if an address is a member of a committee
     * @param committeeId ID of the committee
     * @param member Address to check
     */
    function isMember(uint256 committeeId, address member) public view returns (bool) {
        return committees[committeeId].members[member];
    }

    /**
     * @dev Get the voting power multiplier for a member in a specific committee
     * @param committeeId ID of the committee
     * @param member Address of the member
     */
    function getVotingPowerMultiplier(uint256 committeeId, address member) public view returns (uint256) {
        if (!isMember(committeeId, member)) {
            return 0;
        }
        return committees[committeeId].votingPowerMultiplier;
    }

    /**
     * @dev Check if a function can be proposed by a committee
     * @param committeeId ID of the committee
     * @param functionSelector Function selector to check
     */
    function isFunctionAllowed(uint256 committeeId, bytes4 functionSelector) public view returns (bool) {
        return committees[committeeId].allowedFunctions[functionSelector];
    }
}
