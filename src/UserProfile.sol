// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title UserProfile Contract for Backr Platform
/// @notice Manages user profiles and reputation in the Backr ecosystem
contract UserProfile is AccessControl, Pausable {
    using Counters for Counters.Counter;

    bytes32 public constant REPUTATION_MANAGER_ROLE = keccak256("REPUTATION_MANAGER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    uint256 public constant PROFILE_UPDATE_COOLDOWN = 1 days;
    uint256 public constant RECOVERY_DELAY = 3 days;

    // Structs
    struct Profile {
        string username;
        string bio;
        uint256 reputationScore;
        bool isRegistered;
        uint256 createdAt;
        uint256 lastUpdated;
        bool isVerified;
        string metadata;
        address recoveryAddress;
        uint256 recoveryRequestTime;
    }

    struct ProfileIndex {
        address userAddress;
        uint256 index;
        bool exists;
    }

    // State variables
    mapping(address => Profile) public profiles;
    mapping(string => ProfileIndex) private usernameIndex;
    Counters.Counter private profileCounter;
    uint256 public totalUsers;

    // Events
    event ProfileCreated(address indexed user, string username);
    event ProfileUpdated(address indexed user);
    event ReputationUpdated(address indexed user, uint256 newScore);
    event ProfileVerified(address indexed user);
    event RecoveryAddressSet(address indexed user, address indexed recoveryAddress);
    event RecoveryRequested(address indexed user, uint256 requestTime);
    event RecoveryExecuted(address indexed oldAddress, address indexed newAddress);
    event MetadataUpdated(address indexed user, string metadata);

    // Errors
    error ProfileAlreadyExists();
    error ProfileDoesNotExist();
    error InvalidUsername();
    error UsernameTaken();
    error UpdateTooSoon();
    error NotVerified();
    error InvalidRecoveryAddress();
    error RecoveryDelayNotMet();
    error NoRecoveryRequested();
    error Unauthorized();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Creates a new user profile
    /// @param _username The desired username
    /// @param _bio User's biography/description
    /// @param _metadata Additional profile metadata (IPFS hash)
    function createProfile(string memory _username, string memory _bio, string memory _metadata)
        external
        whenNotPaused
    {
        if (profiles[msg.sender].isRegistered) revert ProfileAlreadyExists();
        if (bytes(_username).length == 0) revert InvalidUsername();
        if (usernameIndex[_username].exists) revert UsernameTaken();

        profiles[msg.sender] = Profile({
            username: _username,
            bio: _bio,
            reputationScore: 0,
            isRegistered: true,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp,
            isVerified: false,
            metadata: _metadata,
            recoveryAddress: address(0),
            recoveryRequestTime: 0
        });

        usernameIndex[_username] =
            ProfileIndex({userAddress: msg.sender, index: profileCounter.current(), exists: true});

        profileCounter.increment();
        totalUsers++;

        emit ProfileCreated(msg.sender, _username);
        emit MetadataUpdated(msg.sender, _metadata);
    }

    /// @notice Updates an existing profile
    /// @param _username New username
    /// @param _bio New biography/description
    /// @param _metadata New metadata
    function updateProfile(string memory _username, string memory _bio, string memory _metadata)
        external
        whenNotPaused
    {
        Profile storage profile = profiles[msg.sender];
        if (!profile.isRegistered) revert ProfileDoesNotExist();
        if (bytes(_username).length == 0) revert InvalidUsername();
        if (block.timestamp < profile.lastUpdated + PROFILE_UPDATE_COOLDOWN) revert UpdateTooSoon();

        // Remove old username index
        delete usernameIndex[profile.username];

        // Check if new username is available
        if (usernameIndex[_username].exists) revert UsernameTaken();

        // Update username index
        usernameIndex[_username] =
            ProfileIndex({userAddress: msg.sender, index: profileCounter.current(), exists: true});

        profile.username = _username;
        profile.bio = _bio;
        profile.metadata = _metadata;
        profile.lastUpdated = block.timestamp;

        emit ProfileUpdated(msg.sender);
        emit MetadataUpdated(msg.sender, _metadata);
    }

    /// @notice Updates a user's reputation score (only callable by authorized contracts)
    /// @param _user Address of the user
    /// @param _newScore New reputation score
    function updateReputation(address _user, uint256 _newScore)
        external
        whenNotPaused
        onlyRole(REPUTATION_MANAGER_ROLE)
    {
        if (!profiles[_user].isRegistered) revert ProfileDoesNotExist();

        profiles[_user].reputationScore = _newScore;
        emit ReputationUpdated(_user, _newScore);
    }

    /// @notice Verifies a user's profile
    /// @param _user Address of the user to verify
    function verifyProfile(address _user) external whenNotPaused onlyRole(VERIFIER_ROLE) {
        Profile storage profile = profiles[_user];
        if (!profile.isRegistered) revert ProfileDoesNotExist();

        profile.isVerified = true;
        emit ProfileVerified(_user);
    }

    /// @notice Sets a recovery address for the profile
    /// @param _recoveryAddress Address that can recover the profile
    function setRecoveryAddress(address _recoveryAddress) external whenNotPaused {
        if (!profiles[msg.sender].isRegistered) revert ProfileDoesNotExist();
        if (_recoveryAddress == address(0)) revert InvalidRecoveryAddress();

        profiles[msg.sender].recoveryAddress = _recoveryAddress;
        emit RecoveryAddressSet(msg.sender, _recoveryAddress);
    }

    /// @notice Initiates profile recovery process
    /// @param _oldAddress Address of the profile to recover
    function initiateRecovery(address _oldAddress) external whenNotPaused {
        Profile storage profile = profiles[_oldAddress];
        if (!profile.isRegistered) revert ProfileDoesNotExist();
        if (msg.sender != profile.recoveryAddress) revert Unauthorized();

        profile.recoveryRequestTime = block.timestamp;
        emit RecoveryRequested(_oldAddress, block.timestamp);
    }

    /// @notice Executes profile recovery
    /// @param _oldAddress Address of the profile to recover
    function executeRecovery(address _oldAddress) external whenNotPaused {
        Profile storage oldProfile = profiles[_oldAddress];
        if (!oldProfile.isRegistered) revert ProfileDoesNotExist();
        if (msg.sender != oldProfile.recoveryAddress) revert Unauthorized();
        if (oldProfile.recoveryRequestTime == 0) revert NoRecoveryRequested();
        if (block.timestamp < oldProfile.recoveryRequestTime + RECOVERY_DELAY) {
            revert RecoveryDelayNotMet();
        }

        // Transfer profile to new address
        profiles[msg.sender] = oldProfile;
        delete profiles[_oldAddress];

        // Update username index
        usernameIndex[oldProfile.username].userAddress = msg.sender;

        emit RecoveryExecuted(_oldAddress, msg.sender);
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

    /// @notice Gets a profile by username
    /// @param _username Username to look up
    /// @return Profile struct containing user information
    function getProfileByUsername(string memory _username) external view returns (Profile memory) {
        ProfileIndex memory index = usernameIndex[_username];
        if (!index.exists) revert ProfileDoesNotExist();
        return profiles[index.userAddress];
    }

    /// @notice Pauses all profile operations
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all profile operations
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
