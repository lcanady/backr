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
    uint256 public constant MAX_REPUTATION = 1000;

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

    // Endorsement system structs
    struct Endorsement {
        address endorser;
        string skill;
        string description;
        uint256 timestamp;
    }

    // Enhanced verification system
    struct VerificationData {
        bool isVerified;
        string verificationType; // e.g., "KYC", "Social", "Professional"
        string verificationProof; // IPFS hash of verification documents
        uint256 verifiedAt;
        address verifier;
    }

    // State variables
    mapping(address => Profile) public profiles;
    mapping(string => ProfileIndex) private usernameIndex;
    Counters.Counter private profileCounter;
    uint256 public totalUsers;

    // Social graph mappings
    mapping(address => address[]) private following;
    mapping(address => address[]) private followers;
    mapping(address => mapping(address => bool)) private isFollowing;
    mapping(address => uint256) public followersCount;
    mapping(address => uint256) public followingCount;

    // Endorsement system mappings
    mapping(address => Endorsement[]) private endorsements;
    mapping(address => mapping(string => uint256)) private skillEndorsementCount;
    mapping(address => mapping(address => mapping(string => bool))) private hasEndorsed;

    // Enhanced verification system mappings
    mapping(address => VerificationData) public verificationData;
    mapping(string => bool) public supportedVerificationTypes;

    // Events
    event ProfileCreated(address indexed user, string username);
    event ProfileUpdated(address indexed user);
    event ReputationUpdated(address indexed user, uint256 newScore);
    event ProfileVerified(address indexed user);
    event RecoveryAddressSet(address indexed user, address indexed recoveryAddress);
    event RecoveryRequested(address indexed user, uint256 requestTime);
    event RecoveryExecuted(address indexed oldAddress, address indexed newAddress);
    event MetadataUpdated(address indexed user, string metadata);
    event FollowUser(address indexed follower, address indexed followed);
    event UnfollowUser(address indexed follower, address indexed unfollowed);
    event EndorsementAdded(address indexed endorser, address indexed endorsed, string skill);
    event EndorsementRemoved(address indexed endorser, address indexed endorsed, string skill);
    event VerificationTypeAdded(string verificationType);
    event VerificationTypeRemoved(string verificationType);
    event ProfileVerificationUpdated(address indexed user, string verificationType, bool verified);

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
    error InvalidReputationScore();

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REPUTATION_MANAGER_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
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
        if (_newScore > MAX_REPUTATION) revert InvalidReputationScore();

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

    /// @notice Enhanced verify profile function
    /// @param _user Address of the user to verify
    /// @param _verificationType Type of verification
    /// @param _verificationProof IPFS hash of verification documents
    function verifyProfileEnhanced(address _user, string calldata _verificationType, string calldata _verificationProof)
        external
        whenNotPaused
        onlyRole(VERIFIER_ROLE)
    {
        if (!profiles[_user].isRegistered) revert ProfileDoesNotExist();
        if (!supportedVerificationTypes[_verificationType]) revert("Unsupported verification type");

        verificationData[_user] = VerificationData({
            isVerified: true,
            verificationType: _verificationType,
            verificationProof: _verificationProof,
            verifiedAt: block.timestamp,
            verifier: msg.sender
        });

        // Update the main profile verification status
        profiles[_user].isVerified = true;

        emit ProfileVerificationUpdated(_user, _verificationType, true);
        emit ProfileVerified(_user);
    }

    /// @notice Revoke profile verification
    /// @param _user Address of the user
    /// @param _verificationType Type of verification to revoke
    function revokeVerification(address _user, string calldata _verificationType)
        external
        whenNotPaused
        onlyRole(VERIFIER_ROLE)
    {
        if (!profiles[_user].isRegistered) revert ProfileDoesNotExist();
        if (!verificationData[_user].isVerified) revert NotVerified();
        if (keccak256(bytes(verificationData[_user].verificationType)) != keccak256(bytes(_verificationType))) {
            revert("Verification type mismatch");
        }

        verificationData[_user].isVerified = false;
        profiles[_user].isVerified = false;

        emit ProfileVerificationUpdated(_user, _verificationType, false);
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

    /// @notice Get verification details for a user
    /// @param _user Address of the user
    /// @return VerificationData struct containing verification details
    function getVerificationDetails(address _user) external view returns (VerificationData memory) {
        if (!profiles[_user].isRegistered) revert ProfileDoesNotExist();
        return verificationData[_user];
    }

    /// @notice Pauses all profile operations
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses all profile operations
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Enhanced verification system functions

    /// @notice Add a supported verification type
    /// @param _verificationType Type of verification to add
    function addVerificationType(string calldata _verificationType) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedVerificationTypes[_verificationType] = true;
        emit VerificationTypeAdded(_verificationType);
    }

    /// @notice Remove a supported verification type
    /// @param _verificationType Type of verification to remove
    function removeVerificationType(string calldata _verificationType) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedVerificationTypes[_verificationType] = false;
        emit VerificationTypeRemoved(_verificationType);
    }

    // Social Graph Functions

    /// @notice Follow another user
    /// @param _userToFollow Address of the user to follow
    function followUser(address _userToFollow) external whenNotPaused {
        if (!profiles[_userToFollow].isRegistered) revert ProfileDoesNotExist();
        if (msg.sender == _userToFollow) revert("Cannot follow yourself");
        if (isFollowing[msg.sender][_userToFollow]) revert("Already following");

        following[msg.sender].push(_userToFollow);
        followers[_userToFollow].push(msg.sender);
        isFollowing[msg.sender][_userToFollow] = true;
        followingCount[msg.sender]++;
        followersCount[_userToFollow]++;

        emit FollowUser(msg.sender, _userToFollow);
    }

    /// @notice Unfollow a user
    /// @param _userToUnfollow Address of the user to unfollow
    function unfollowUser(address _userToUnfollow) external whenNotPaused {
        if (!isFollowing[msg.sender][_userToUnfollow]) revert("Not following");

        // Remove from following array
        for (uint256 i = 0; i < following[msg.sender].length; i++) {
            if (following[msg.sender][i] == _userToUnfollow) {
                following[msg.sender][i] = following[msg.sender][following[msg.sender].length - 1];
                following[msg.sender].pop();
                break;
            }
        }

        // Remove from followers array
        for (uint256 i = 0; i < followers[_userToUnfollow].length; i++) {
            if (followers[_userToUnfollow][i] == msg.sender) {
                followers[_userToUnfollow][i] = followers[_userToUnfollow][followers[_userToUnfollow].length - 1];
                followers[_userToUnfollow].pop();
                break;
            }
        }

        isFollowing[msg.sender][_userToUnfollow] = false;
        followingCount[msg.sender]--;
        followersCount[_userToUnfollow]--;

        emit UnfollowUser(msg.sender, _userToUnfollow);
    }

    /// @notice Get list of addresses that a user is following
    /// @param _user Address of the user
    /// @return Array of addresses being followed
    function getFollowing(address _user) external view returns (address[] memory) {
        return following[_user];
    }

    /// @notice Get list of addresses that follow a user
    /// @param _user Address of the user
    /// @return Array of follower addresses
    function getFollowers(address _user) external view returns (address[] memory) {
        return followers[_user];
    }

    /// @notice Check if one user is following another
    /// @param _follower Address of the potential follower
    /// @param _followed Address of the potentially followed user
    /// @return bool indicating if _follower is following _followed
    function checkFollowing(address _follower, address _followed) external view returns (bool) {
        return isFollowing[_follower][_followed];
    }

    // Endorsement System Functions

    /// @notice Add an endorsement for a user's skill
    /// @param _user Address of the user to endorse
    /// @param _skill Name of the skill to endorse
    /// @param _description Description of the endorsement
    function addEndorsement(address _user, string calldata _skill, string calldata _description)
        external
        whenNotPaused
    {
        if (!profiles[_user].isRegistered) revert ProfileDoesNotExist();
        if (msg.sender == _user) revert("Cannot endorse yourself");
        if (hasEndorsed[msg.sender][_user][_skill]) revert("Already endorsed this skill");

        endorsements[_user].push(
            Endorsement({endorser: msg.sender, skill: _skill, description: _description, timestamp: block.timestamp})
        );

        skillEndorsementCount[_user][_skill]++;
        hasEndorsed[msg.sender][_user][_skill] = true;

        emit EndorsementAdded(msg.sender, _user, _skill);
    }

    /// @notice Remove an endorsement for a user's skill
    /// @param _user Address of the user
    /// @param _skill Name of the skill
    function removeEndorsement(address _user, string calldata _skill) external whenNotPaused {
        if (!hasEndorsed[msg.sender][_user][_skill]) revert("No endorsement found");

        uint256 endorsementIndex;
        bool found;

        for (uint256 i = 0; i < endorsements[_user].length; i++) {
            if (
                endorsements[_user][i].endorser == msg.sender
                    && keccak256(bytes(endorsements[_user][i].skill)) == keccak256(bytes(_skill))
            ) {
                endorsementIndex = i;
                found = true;
                break;
            }
        }

        require(found, "Endorsement not found");

        // Remove endorsement by swapping with last element and popping
        endorsements[_user][endorsementIndex] = endorsements[_user][endorsements[_user].length - 1];
        endorsements[_user].pop();

        skillEndorsementCount[_user][_skill]--;
        hasEndorsed[msg.sender][_user][_skill] = false;

        emit EndorsementRemoved(msg.sender, _user, _skill);
    }

    /// @notice Get all endorsements for a user
    /// @param _user Address of the user
    /// @return Array of endorsements
    function getEndorsements(address _user) external view returns (Endorsement[] memory) {
        return endorsements[_user];
    }

    /// @notice Get endorsement count for a specific skill
    /// @param _user Address of the user
    /// @param _skill Name of the skill
    /// @return Number of endorsements for the skill
    function getSkillEndorsementCount(address _user, string calldata _skill) external view returns (uint256) {
        return skillEndorsementCount[_user][_skill];
    }

    /// @notice Check if a user has endorsed another user for a specific skill
    /// @param _endorser Address of the potential endorser
    /// @param _endorsed Address of the potentially endorsed user
    /// @param _skill Name of the skill
    /// @return bool indicating if the endorsement exists
    function hasEndorsedSkill(address _endorser, address _endorsed, string calldata _skill)
        external
        view
        returns (bool)
    {
        return hasEndorsed[_endorser][_endorsed][_skill];
    }
}
