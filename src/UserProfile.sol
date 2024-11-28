// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title UserProfile Contract for Backr Platform
/// @notice Manages user profiles and reputation in the Backr ecosystem
contract UserProfile {
    // Structs
    struct Profile {
        string username;
        string bio;
        uint256 reputationScore;
        bool isRegistered;
        uint256 createdAt;
        uint256 lastUpdated;
    }

    // State variables
    mapping(address => Profile) public profiles;
    uint256 public totalUsers;

    // Events
    event ProfileCreated(address indexed user, string username);
    event ProfileUpdated(address indexed user);
    event ReputationUpdated(address indexed user, uint256 newScore);

    // Errors
    error ProfileAlreadyExists();
    error ProfileDoesNotExist();
    error InvalidUsername();

    /// @notice Creates a new user profile
    /// @param _username The desired username
    /// @param _bio User's biography/description
    function createProfile(string memory _username, string memory _bio) external {
        if (profiles[msg.sender].isRegistered) revert ProfileAlreadyExists();
        if (bytes(_username).length == 0) revert InvalidUsername();

        profiles[msg.sender] = Profile({
            username: _username,
            bio: _bio,
            reputationScore: 0,
            isRegistered: true,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp
        });

        totalUsers++;
        emit ProfileCreated(msg.sender, _username);
    }

    /// @notice Updates an existing profile
    /// @param _username New username
    /// @param _bio New biography/description
    function updateProfile(string memory _username, string memory _bio) external {
        if (!profiles[msg.sender].isRegistered) revert ProfileDoesNotExist();
        if (bytes(_username).length == 0) revert InvalidUsername();

        Profile storage profile = profiles[msg.sender];
        profile.username = _username;
        profile.bio = _bio;
        profile.lastUpdated = block.timestamp;

        emit ProfileUpdated(msg.sender);
    }

    /// @notice Updates a user's reputation score (only callable by authorized contracts)
    /// @param _user Address of the user
    /// @param _newScore New reputation score
    function updateReputation(address _user, uint256 _newScore) external {
        // TODO: Add access control to restrict this to authorized contracts
        if (!profiles[_user].isRegistered) revert ProfileDoesNotExist();
        
        profiles[_user].reputationScore = _newScore;
        emit ReputationUpdated(_user, _newScore);
    }

    /// @notice Checks if a profile exists
    /// @param _user Address to check
    /// @return bool indicating if the profile exists
    function hasProfile(address _user) external view returns (bool) {
        return profiles[_user].isRegistered;
    }

    /// @notice Gets a user's profile
    /// @param _user Address of the user
    /// @return Profile struct containing user information
    function getProfile(address _user) external view returns (Profile memory) {
        if (!profiles[_user].isRegistered) revert ProfileDoesNotExist();
        return profiles[_user];
    }
}
