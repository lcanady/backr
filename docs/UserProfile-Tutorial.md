# User Profile Tutorial

The UserProfile contract manages user profiles and reputation in the Backr ecosystem. This tutorial covers how to interact with the contract's various features.

## Table of Contents
1. [Basic Profile Management](#basic-profile-management)
2. [Profile Verification](#profile-verification)
3. [Reputation System](#reputation-system)
4. [Profile Recovery](#profile-recovery)
5. [Social Graph Features](#social-graph-features)
6. [Endorsement System](#endorsement-system)
7. [Administrative Functions](#administrative-functions)
8. [Profile Metadata Standards](#profile-metadata-standards)

## Basic Profile Management

### Creating a Profile

To create a new profile:

```solidity
userProfile.createProfile(
    "alice",              // username
    "Web3 developer",     // bio
    "ipfs://metadata1"    // metadata (IPFS hash)
);
```

Requirements:
- You cannot create multiple profiles for the same address
- Usernames must be unique
- Username cannot be empty

### Updating a Profile

To update an existing profile:

```solidity
userProfile.updateProfile(
    "alice_updated",           // new username
    "Senior Web3 developer",   // new bio
    "ipfs://metadata2"        // new metadata
);
```

Requirements:
- Must wait 1 day between updates (PROFILE_UPDATE_COOLDOWN)
- New username must be unique
- Username cannot be empty

## Profile Verification

The contract supports two types of verification:

### Basic Verification

Can only be performed by addresses with the VERIFIER_ROLE:

```solidity
userProfile.verifyProfile(userAddress);
```

### Enhanced Verification

Supports different types of verification with additional metadata:

```solidity
userProfile.verifyProfileEnhanced(
    userAddress,
    "KYC",                    // verification type
    "ipfs://verification123"  // verification proof
);
```

Verification can also be revoked:

```solidity
userProfile.revokeVerification(userAddress, "KYC");
```

## Reputation System

### Updating Reputation

Can only be performed by addresses with the REPUTATION_MANAGER_ROLE:

```solidity
userProfile.updateReputation(userAddress, 100);
```

Requirements:
- Score must be between 0 and 1000 (MAX_REPUTATION)
- User must have a registered profile

## Profile Recovery

The recovery system allows users to recover access to their profile if they lose access to their original address.

### Setting Recovery Address

```solidity
userProfile.setRecoveryAddress(recoveryAddress);
```

### Recovery Process

1. Initiate recovery (must be called by recovery address):
```solidity
userProfile.initiateRecovery(oldAddress);
```

2. Execute recovery after delay (must be called by recovery address):
```solidity
userProfile.executeRecovery(oldAddress);
```

Requirements:
- Must wait 3 days (RECOVERY_DELAY) between initiation and execution
- Only the designated recovery address can perform these actions

## Social Graph Features

### Following Users

```solidity
userProfile.followUser(addressToFollow);
```

Requirements:
- Cannot follow yourself
- Cannot follow the same user twice
- User must have a registered profile

### Unfollowing Users

```solidity
userProfile.unfollowUser(addressToUnfollow);
```

### Viewing Social Connections

```solidity
// Get list of addresses user is following
address[] following = userProfile.getFollowing(userAddress);

// Get list of followers
address[] followers = userProfile.getFollowers(userAddress);

// Check if one user follows another
bool isFollowing = userProfile.checkFollowing(follower, followed);
```

## Endorsement System

### Adding Endorsements

```solidity
userProfile.addEndorsement(
    userAddress,
    "Solidity",              // skill
    "Excellent developer"    // description
);
```

Requirements:
- Cannot endorse yourself
- Cannot endorse the same skill twice
- User must have a registered profile

### Removing Endorsements

```solidity
userProfile.removeEndorsement(userAddress, "Solidity");
```

### Viewing Endorsements

```solidity
// Get all endorsements
Endorsement[] endorsements = userProfile.getEndorsements(userAddress);

// Get count for specific skill
uint256 count = userProfile.getSkillEndorsementCount(userAddress, "Solidity");

// Check if user has endorsed a skill
bool hasEndorsed = userProfile.hasEndorsedSkill(endorser, endorsed, "Solidity");
```

## Administrative Functions

### Role Management

The contract uses OpenZeppelin's AccessControl with the following roles:
- DEFAULT_ADMIN_ROLE: Can grant/revoke other roles
- REPUTATION_MANAGER_ROLE: Can update user reputation
- VERIFIER_ROLE: Can verify profiles

### Pausing

The contract can be paused by the admin to stop all operations:

```solidity
// Pause
userProfile.pause();

// Unpause
userProfile.unpause();
```

### Verification Types

Admins can manage supported verification types:

```solidity
// Add verification type
userProfile.addVerificationType("KYC");

// Remove verification type
userProfile.removeVerificationType("KYC");
```

## Profile Metadata Standards

The UserProfile contract uses IPFS for storing extended profile metadata. The metadata field in the Profile struct expects an IPFS URI that points to a JSON file containing additional profile information.

### Metadata Format

The metadata JSON should follow this structure:

```json
{
  "version": "1.0",
  "name": "Display Name",
  "avatar": "ipfs://...",  // IPFS hash of profile image
  "banner": "ipfs://...",  // IPFS hash of profile banner image
  "description": "Extended bio/description",
  "links": {
    "website": "https://...",
    "twitter": "https://twitter.com/...",
    "github": "https://github.com/...",
    "linkedin": "https://linkedin.com/in/..."
  },
  "skills": [
    {
      "name": "Solidity",
      "level": "Expert",
      "years": 3
    },
    {
      "name": "Web3",
      "level": "Intermediate", 
      "years": 2
    }
  ],
  "achievements": [
    {
      "title": "Hackathon Winner",
      "date": "2023-01-01",
      "description": "First place in ETHGlobal hackathon",
      "proof": "ipfs://..." // Optional proof/certificate
    }
  ],
  "preferences": {
    "displayEmail": false,
    "availableForWork": true,
    "timezone": "UTC-5",
    "languages": ["en", "es"]
  }
}
```

### Metadata Events

The contract emits a `MetadataUpdated` event whenever profile metadata changes:

```solidity
event MetadataUpdated(address indexed user, string metadata);
```

This event can be monitored to track profile updates and keep any external systems in sync.

### Best Practices

1. Always validate metadata JSON schema before uploading to IPFS
2. Use permanent IPFS pins for metadata storage
3. Keep metadata size reasonable (recommended < 100KB)
4. Update metadata atomically with profile changes
5. Include version field for future compatibility

## Query Functions

### Profile Information

```solidity
// Check if address has profile
bool exists = userProfile.hasProfile(address);

// Get profile by address
Profile profile = userProfile.getProfile(address);

// Get profile by username
Profile profile = userProfile.getProfileByUsername("alice");

// Get verification details
VerificationData data = userProfile.getVerificationDetails(address);
```

## Events

The contract emits various events that can be monitored:
- ProfileCreated(address indexed user, string username)
- ProfileUpdated(address indexed user)
- ReputationUpdated(address indexed user, uint256 newScore)
- ProfileVerified(address indexed user)
- RecoveryAddressSet(address indexed user, address indexed recoveryAddress)
- RecoveryRequested(address indexed user, uint256 requestTime)
- RecoveryExecuted(address indexed oldAddress, address indexed newAddress)
- MetadataUpdated(address indexed user, string metadata)
- FollowUser(address indexed follower, address indexed followed)
- UnfollowUser(address indexed follower, address indexed unfollowed)
- EndorsementAdded(address indexed endorser, address indexed endorsed, string skill)
- EndorsementRemoved(address indexed endorser, address indexed endorsed, string skill)
- VerificationTypeAdded(string verificationType)
- VerificationTypeRemoved(string verificationType)
- ProfileVerificationUpdated(address indexed user, string verificationType, bool verified)
