# Backr

Backr is a decentralized platform built on Ethereum that enables transparent and accountable project funding through milestone-based releases and community governance. The platform incorporates quadratic funding mechanisms, liquidity pools, and achievement badges to create a robust ecosystem for project creators and backers.

## Key Features

### 🎯 Milestone-Based Project Funding
- Create projects with detailed milestones
- Secure fund release through community voting
- Transparent progress tracking

### 🏛 Decentralized Governance
- Community-driven decision making
- Proposal creation and voting system
- Time-locked execution for security

### 💧 Liquidity Pool
- Automated Market Maker (AMM) for ETH/BACKR trading
- Low 0.3% fee structure
- Minimum liquidity requirements for stability

### 🏆 Achievement Badges
- NFT-based recognition system
- Multiple badge types:
  - Early Supporter
  - Power Backer
  - Liquidity Provider
  - Governance Active
- Stackable benefits up to 25%

### 💫 Quadratic Funding
- Fair fund distribution
- Matching pool for contributions
- Round-based funding cycles

## Architecture

### Smart Contracts

- `Project.sol`: Core contract managing project creation and milestone tracking
- `Governance.sol`: DAO functionality for platform governance
- `LiquidityPool.sol`: AMM implementation for token liquidity
- `Badge.sol`: NFT-based achievement system
- `QuadraticFunding.sol`: Implementation of quadratic funding mechanism
- `PlatformToken.sol`: BACKR token with staking capabilities
- `UserProfile.sol`: User reputation and profile management

### Security Features
- Reentrancy guards
- Time-locked execution
- Access control mechanisms
- Minimum liquidity requirements
- Pausable functionality

## Development

### Technical Stack

- Solidity ^0.8.13
- OpenZeppelin Contracts
- [Foundry](https://book.getfoundry.sh/) - Development Framework

### Prerequisites

- [Foundry toolkit](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm
- Git

### Local Setup

1. Clone the repository
```shell
git clone https://github.com/yourusername/backr.git
cd backr
```

2. Install dependencies
```shell
forge install
```

3. Build the project
```shell
forge build
```

4. Run tests
```shell
forge test
```

5. Format code
```shell
forge fmt
```

6. Check gas usage
```shell
forge snapshot
```

### Local Development

1. Start local node
```shell
anvil
```

2. Deploy Protocol Contracts

The deployment order matters due to contract dependencies. Use the following commands:

```shell
# Deploy UserProfile contract first
forge script script/deploy/DeployUserProfile.s.sol:DeployUserProfile --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Deploy PlatformToken
forge script script/deploy/DeployPlatformToken.s.sol:DeployPlatformToken --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Deploy Badge system (requires PlatformToken address)
forge script script/deploy/DeployBadge.s.sol:DeployBadge --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Deploy Governance (requires PlatformToken address)
forge script script/deploy/DeployGovernance.s.sol:DeployGovernance --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Deploy LiquidityPool (requires PlatformToken address)
forge script script/deploy/DeployLiquidityPool.s.sol:DeployLiquidityPool --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Deploy Project contract (requires UserProfile address)
forge script script/deploy/DeployProject.s.sol:DeployProject --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# Deploy QuadraticFunding (requires Project contract address)
forge script script/deploy/DeployQuadraticFunding.s.sol:DeployQuadraticFunding --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
```

For testnet or mainnet deployment, replace `http://localhost:8545` with your network RPC URL.

3. Verify Contracts (for public networks)
```shell
forge verify-contract --chain-id <CHAIN_ID> \
    --compiler-version <COMPILER_VERSION> \
    <CONTRACT_ADDRESS> \
    <CONTRACT_NAME> \
    <ETHERSCAN_API_KEY>
```

4. Initialize Protocol

After deployment, the following initialization steps are required:

```shell
# Initialize LiquidityPool with initial liquidity
cast send --private-key $PRIVATE_KEY <LIQUIDITY_POOL_ADDRESS> \
    "addLiquidity(uint256)" \
    <TOKEN_AMOUNT> \
    --value <ETH_AMOUNT>

# Set up initial governance parameters
cast send --private-key $PRIVATE_KEY <GOVERNANCE_ADDRESS> \
    "initialize()" 

# Initialize QuadraticFunding with first round
cast send --private-key $PRIVATE_KEY <QUADRATIC_FUNDING_ADDRESS> \
    "startRound()" \
    --value <MATCHING_POOL_AMOUNT>
```

### Additional Commands

For more detailed information about available commands:
```shell
forge --help
anvil --help
cast --help
```

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License.

## TODO

### UserProfile Contract
- [x] Add access control to updateReputation function
- [x] Implement rate limiting for profile updates
- [x] Add profile verification system
- [x] Create profile indexing for efficient querying
- [x] Add profile metadata standards for better interoperability
- [x] Implement profile recovery mechanism

### LiquidityPool Contract
- [x] Add slippage protection for swaps
- [x] Implement emergency withdrawal mechanism
- [x] Add events for pool state changes

### Governance Contract
- [x] Add proposal execution timelock
- [x] Implement delegate voting
- [x] Add proposal cancellation mechanism

### Badge Contract
- [x] Add badge metadata and URI standards
- [x] Implement badge revoking mechanism
- [x] Add badge progression system

### QuadraticFunding Contract
- [x] Add round cancellation mechanism
- [x] Implement matching pool contribution mechanism
- [x] Add contribution verification and validation
- [x] Implement quadratic funding calculation formula
- [x] Create round creation and configuration system
- [x] Add participant eligibility verification
- [x] Implement fund distribution mechanism
- [x] Create reporting and analytics system
