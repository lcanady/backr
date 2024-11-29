# Backr

Backr is a decentralized platform built on Ethereum that enables transparent and accountable project funding through milestone-based releases and community governance. The platform incorporates quadratic funding mechanisms, liquidity pools, and achievement badges to create a robust ecosystem for project creators and backers.

## Key Features

### 👤 Enhanced User Profiles
- Verified profiles with trusted verification system
- Profile recovery mechanism with time-locked security
- Reputation scoring system
- Profile metadata standards for better interoperability
- Username indexing for efficient querying

### 🎯 Milestone-Based Project Funding
- Create projects with detailed milestones
- Secure fund release through community voting
- Transparent progress tracking
- Project analytics and reporting

### 🏛 Decentralized Governance
- Community-driven decision making
- Proposal creation and voting system
- Time-locked execution for security
- Multi-role access control system

### 💧 Liquidity Pool
- Automated Market Maker (AMM) for ETH/BACKR trading
- Advanced slippage protection
- Emergency withdrawal mechanisms
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

### 💫 Advanced Quadratic Funding
- Fair fund distribution with matching pools
- Round-based funding cycles with configurable parameters
- Eligibility verification for participants
- Comprehensive round analytics
- Minimum and maximum contribution limits
- Anti-sybil mechanisms

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
- Ethereum Development Environment
  - Local: Anvil (Foundry's built-in local testnet)
  - Testnet: Sepolia
  - Mainnet: Ethereum

### Prerequisites

- [Foundry toolkit](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm (for additional tooling)
- Git
- An Ethereum wallet with testnet ETH (for testnet deployment)
- RPC URLs for your desired networks (local, testnet, or mainnet)

### Project Structure

```
backr/
├── src/                    # Smart contract source files
│   ├── PlatformToken.sol   # BACKR token implementation
│   ├── UserProfile.sol     # User profile management
│   ├── Project.sol         # Project and milestone management
│   └── QuadraticFunding.sol# Quadratic funding implementation
├── script/                 # Deployment and interaction scripts
│   └── Deploy.s.sol        # Main deployment script
├── test/                   # Test files
├── lib/                    # Dependencies
├── .env                    # Environment variables (git-ignored)
└── foundry.toml           # Foundry configuration
```

### Development Workflow

1. **Local Development**
   ```shell
   # Start a local Ethereum node
   anvil

   # In a new terminal, deploy to local network
   forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --private-key <PRIVATE_KEY> --broadcast

   # Initialize the protocol with funding and sample data
   forge script script/Setup.s.sol:SetupScript --rpc-url http://localhost:8545 --private-key <PRIVATE_KEY> --broadcast
   ```

2. **Testing**
   ```shell
   # Run all tests
   forge test
   
   # Run specific test file
   forge test --match-path test/Project.t.sol
   
   # Run tests with verbosity
   forge test -vvv
   
   # Run tests and show gas report
   forge test --gas-report
   ```

3. **Code Quality**
   ```shell
   # Format code
   forge fmt
   
   # Check gas usage
   forge snapshot
   
   # Run static analysis (if slither is installed)
   slither .
   ```

4. **Contract Verification**
   ```shell
   # Verify on Etherscan (after deployment)
   forge verify-contract <DEPLOYED_ADDRESS> src/Contract.sol:Contract --chain-id <CHAIN_ID> --api-key $ETHERSCAN_API_KEY
   ```

### Deployment

1. Set up your environment variables by creating a `.env` file:
```shell
PRIVATE_KEY=your_private_key_here
```

2. Deploy the contracts:
```shell
# For local deployment (Anvil)
forge script script/Deploy.s.sol:DeployScript --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast

# For testnet deployment (Sepolia)
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify

# For mainnet deployment
forge script script/Deploy.s.sol:DeployScript --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

The deployment script will:
1. Deploy PlatformToken
2. Deploy UserProfile
3. Deploy Project (with UserProfile dependency)
4. Deploy QuadraticFunding (with Project dependency)

3. Initialize the protocol:
```shell
# For local deployment (Anvil)
forge script script/Setup.s.sol:SetupScript --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
```

The setup script will:
1. Create a profile for the deployer
2. Create an initial funding round with a 10 ETH matching pool
3. Create a sample project with one milestone (1 ETH funding, 10 votes required)
4. Verify the deployer as an eligible participant
5. Make an initial contribution of 1 ETH to the sample project

After deployment and setup, save the deployed contract addresses for future reference. The setup script will output these addresses in the console.

### Protocol Initialization

After deployment, the protocol will be initialized with:

- **User Profile**: A deployer profile with basic metadata
- **Funding Round**: Active round with:
  - 10 ETH matching pool
  - 14-day duration
  - Min contribution: 0.01 ETH
  - Max contribution: 10 ETH
- **Sample Project**: Initial project with:
  - Single milestone
  - 1 ETH funding requirement
  - 10 votes needed for completion
- **Initial Funding**: 1 ETH contributed to the sample project

### Common Tasks

1. **Compile Contracts**
   ```shell
   forge build
   ```

2. **Clean Build Files**
   ```shell
   forge clean
   ```

3. **Update Dependencies**
   ```shell
   forge update
   ```

4. **Generate Gas Report**
   ```shell
   forge test --gas-report > gas-report.txt
   ```

### Best Practices

1. Always run tests before deploying
2. Keep your private keys and API keys secure
3. Use the gas reporter to optimize expensive functions
4. Verify contracts after deployment for transparency
5. Document any deployed contract addresses
6. Test on testnet before mainnet deployment

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
