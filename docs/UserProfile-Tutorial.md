# UserProfile Contract Tutorial

This tutorial explains how to interact with the UserProfile contract, which manages user profiles, reputation, social connections, and endorsements on the Backr platform.

## Core Features

1. Profile Management
2. Verification System
3. Social Graph (Following/Followers)
4. Endorsement System
5. Profile Recovery

## Profile Management

### Creating a Profile

To participate in the Backr platform, users must first create a profile:

```solidity
userProfile.createProfile(
    "alice_dev",           // username
    "Blockchain Developer", // bio
    "ipfs://Qm..."         // metadata IPFS hash
);
```

**Important Notes**:
- Usernames must be unique
- Profiles cannot be created while the contract is paused
- Each address can only have one profile

### Updating a Profile

Profiles can be updated with a 24-hour cooldown period:

```solidity
userProfile.updateProfile(
    "alice_web3",          // new username
    "Senior Web3 Dev",     // new bio
    "ipfs://Qm..."         // new metadata IPFS hash
);
```

**Restrictions**:
- Must wait 24 hours between updates
- New username must be unique
- Cannot update while contract is paused

### Checking Profile Status

```solidity
// Check if an address has a profile
bool hasProfile = userProfile.hasProfile(address);

// Get profile details
Profile memory profile = userProfile.getProfile(address);

// Look up profile by username
Profile memory profile = userProfile.getProfileByUsername("alice_dev");
```

## Verification System

The platform supports multiple types of verification:

### Basic Verification
Only accessible by addresses with VERIFIER_ROLE:

```solidity
userProfile.verifyProfile(userAddress);
```

### Enhanced Verification
Supports different verification types with proof:

```solidity
userProfile.verifyProfileEnhanced(
    userAddress,
    "KYC",                // verification type
    "ipfs://Qm..."        // verification proof
);
```

### Checking Verification Status

```solidity
VerificationData memory data = userProfile.getVerificationDetails(userAddress);
```

## Social Graph Features

### Following Users

```solidity
// Follow a user
userProfile.followUser(addressToFollow);

// Unfollow a user
userProfile.unfollowUser(addressToUnfollow);
```

### Viewing Social Connections

```solidity
// Get following list
address[] memory following = userProfile.getFollowing(userAddress);

// Get followers list
address[] memory followers = userProfile.getFollowers(userAddress);

// Check if following
bool isFollowing = userProfile.checkFollowing(follower, followed);

// Get counts
uint256 followersCount = userProfile.followersCount(userAddress);
uint256 followingCount = userProfile.followingCount(userAddress);
```

## Endorsement System

### Adding Endorsements

```solidity
userProfile.addEndorsement(
    userAddress,
    "Solidity",           // skill
    "Excellent developer" // description
);
```

**Rules**:
- Cannot endorse yourself
- Cannot endorse the same skill twice
- User must have a profile

### Managing Endorsements

```solidity
// Remove an endorsement
userProfile.removeEndorsement(userAddress, "Solidity");

// View endorsements
Endorsement[] memory endorsements = userProfile.getEndorsements(userAddress);

// Get skill endorsement count
uint256 count = userProfile.getSkillEndorsementCount(userAddress, "Solidity");

// Check if endorsed
bool hasEndorsed = userProfile.hasEndorsedSkill(endorser, endorsed, "Solidity");
```

## Profile Recovery

The platform includes a secure recovery system for lost access:

### Setting Up Recovery

```solidity
// Set recovery address
userProfile.setRecoveryAddress(recoveryAddress);
```

### Recovery Process

1. Initiate Recovery:
```solidity
userProfile.initiateRecovery(oldAddress);
```

2. Execute Recovery (after 3-day delay):
```solidity
userProfile.executeRecovery(oldAddress);
```

**Important Notes**:
- Must wait 3 days between initiation and execution
- Only the recovery address can initiate and execute
- All profile data is transferred to the new address

## Events to Monitor

The contract emits various events for tracking changes:

1. Profile Management:
   - `ProfileCreated(address user, string username)`
   - `ProfileUpdated(address user)`
   - `MetadataUpdated(address user, string metadata)`

2. Verification:
   - `ProfileVerified(address user)`
   - `ProfileVerificationUpdated(address user, string verificationType, bool verified)`

3. Social:
   - `FollowUser(address follower, address followed)`
   - `UnfollowUser(address follower, address unfollowed)`

4. Endorsements:
   - `EndorsementAdded(address endorser, address endorsed, string skill)`
   - `EndorsementRemoved(address endorser, address endorsed, string skill)`

5. Recovery:
   - `RecoveryAddressSet(address user, address recoveryAddress)`
   - `RecoveryRequested(address user, uint256 requestTime)`
   - `RecoveryExecuted(address oldAddress, address newAddress)`

## Error Handling

Common errors you might encounter:

```solidity
ProfileAlreadyExists()    // Address already has a profile
ProfileDoesNotExist()     // Profile not found
InvalidUsername()         // Empty username
UsernameTaken()          // Username already in use
UpdateTooSoon()          // Cooldown period not met
NotVerified()            // Profile not verified
InvalidRecoveryAddress() // Invalid recovery address
RecoveryDelayNotMet()    // 3-day delay not met
NoRecoveryRequested()    // Recovery not initiated
Unauthorized()           // Not authorized for action
InvalidReputationScore() // Score exceeds maximum
```

## Best Practices

1. **Profile Creation**
   - Choose a unique, meaningful username
   - Provide comprehensive bio information
   - Store detailed metadata in IPFS

2. **Profile Updates**
   - Plan updates around cooldown period
   - Maintain consistent username scheme
   - Keep metadata current

3. **Social Interactions**
   - Verify profiles before following
   - Build meaningful connections
   - Regularly update social graph

4. **Endorsements**
   - Provide detailed endorsement descriptions
   - Endorse specific, verifiable skills
   - Maintain professional endorsement practices

5. **Security**
   - Set up recovery address immediately
   - Store recovery information securely
   - Regularly verify profile settings

## Testing Example

Here's a complete example of setting up and using a profile:

```solidity
// 1. Create profile
userProfile.createProfile(
    "dev_alice",
    "Blockchain Developer specializing in DeFi",
    "ipfs://Qm..."
);

// 2. Set recovery address
userProfile.setRecoveryAddress(recoveryWallet);

// 3. Follow other users
userProfile.followUser(otherDev);

// 4. Add endorsements
userProfile.addEndorsement(
    otherDev,
    "Smart Contracts",
    "Excellent Solidity developer, worked together on DeFi project"
);

// 5. Check profile status
Profile memory myProfile = userProfile.getProfile(address(this));
VerificationData memory verificationStatus = userProfile.getVerificationDetails(address(this));
