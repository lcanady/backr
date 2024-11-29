// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TeamManagement
 * @notice Manages team profiles, delegations, and collaboration
 */
contract TeamManagement {
    // Enum for team member roles
    enum TeamRole {
        Owner,
        Admin,
        Member,
        Viewer
    }

    // Struct to represent a team member
    struct TeamMember {
        address memberAddress;
        string name;
        string email;
        TeamRole role;
        bool isActive;
    }

    // Struct for delegation
    struct Delegation {
        address delegator;
        address delegatee;
        uint256 validUntil;
        bool isActive;
    }

    // Mapping of project address to team members
    mapping(address => TeamMember[]) public projectTeams;

    // Mapping of delegations
    mapping(address => Delegation) public delegations;

    // Events
    event TeamMemberAdded(address indexed project, address indexed member, TeamRole role);

    event DelegationCreated(address indexed delegator, address indexed delegatee, uint256 validUntil);

    event DelegationRevoked(address indexed delegator, address indexed delegatee);

    /**
     * @notice Add a team member to a project
     * @param _project Project address
     * @param _member Member's address
     * @param _name Member's name
     * @param _email Member's email
     * @param _role Member's role in the project
     */
    function addTeamMember(address _project, address _member, string memory _name, string memory _email, TeamRole _role)
        public
    {
        // Validate member doesn't already exist
        for (uint256 i = 0; i < projectTeams[_project].length; i++) {
            require(projectTeams[_project][i].memberAddress != _member, "Member already exists");
        }

        projectTeams[_project].push(
            TeamMember({memberAddress: _member, name: _name, email: _email, role: _role, isActive: true})
        );

        emit TeamMemberAdded(_project, _member, _role);
    }

    /**
     * @notice Create a delegation
     * @param _delegatee Address receiving delegation
     * @param _validUntil Timestamp until which delegation is valid
     */
    function createDelegation(address _delegatee, uint256 _validUntil) public {
        require(_validUntil > block.timestamp, "Invalid delegation period");

        delegations[msg.sender] =
            Delegation({delegator: msg.sender, delegatee: _delegatee, validUntil: _validUntil, isActive: true});

        emit DelegationCreated(msg.sender, _delegatee, _validUntil);
    }

    /**
     * @notice Revoke an existing delegation
     */
    function revokeDelegation() public {
        require(delegations[msg.sender].isActive, "No active delegation");

        address delegatee = delegations[msg.sender].delegatee;
        delete delegations[msg.sender];

        emit DelegationRevoked(msg.sender, delegatee);
    }

    /**
     * @notice Check if a delegation is active
     * @param _delegator Address of the delegator
     * @return Whether the delegation is active and valid
     */
    function isDelegationActive(address _delegator) public view returns (bool) {
        Delegation memory delegation = delegations[_delegator];
        return delegation.isActive && delegation.validUntil > block.timestamp;
    }

    /**
     * @notice Get delegatee for a given delegator
     * @param _delegator Address of the delegator
     * @return Address of the delegatee
     */
    function getDelegatee(address _delegator) public view returns (address) {
        return isDelegationActive(_delegator) ? delegations[_delegator].delegatee : _delegator;
    }

    /**
     * @notice Get team members for a project
     * @param _project Project address
     * @return Array of team members
     */
    function getProjectTeamMembers(address _project) public view returns (TeamMember[] memory) {
        return projectTeams[_project];
    }
}
