# Backr

Backr is a decentralized platform built on Ethereum that enables transparent and accountable project funding through milestone-based releases and community governance. The platform incorporates quadratic funding mechanisms, liquidity pools, and achievement badges to create a robust ecosystem for project creators and backers.

## Key Features

### 👤 Enhanced User Profiles
- Verified profiles with multi-type verification system (KYC, Social, Professional)
- Profile recovery mechanism with time-locked security
- Reputation scoring system
- Profile metadata standards for better interoperability
- Username indexing for efficient querying
- Social graph functionality with following/follower relationships
- Skill-based endorsement system
- Project portfolio showcase with featured items
- IPFS-based verification proof storage

### 🎯 Milestone-Based Project Funding
- Create projects with detailed milestones
- Secure fund release through community voting
- Transparent progress tracking
- Project analytics and reporting
- Template-based project creation
- Multi-category project organization

### 🏛 Advanced Governance System
- Community-driven decision making through multiple mechanisms:
  - Standard proposal voting
  - Committee-based governance for specialized decisions
  - Gasless voting for improved accessibility
- Time-locked execution for security
- Multi-role access control system
- Proposal templates for standardized governance
- Delegation capabilities with granular controls

### 💧 Liquidity Management
- Automated Market Maker (AMM) for ETH/BACKR trading
- Advanced slippage protection
- Emergency withdrawal mechanisms
- Liquidity incentives program
- Low 0.3% fee structure
- Minimum liquidity requirements for stability

### 🏆 Achievement System
- Dynamic NFT-based recognition system
- Multiple badge types with unique benefits
- Badge Marketplace features:
  - Trade badges on the open market
  - Dynamic pricing based on rarity
  - Secure escrow-based trading
  - Achievement-locked minting
  - Badge bundling capabilities

### 💫 Advanced Quadratic Funding
- Fair fund distribution with matching pools
- Round-based funding cycles
- Eligibility verification
- Comprehensive analytics
- Anti-sybil mechanisms
- Configurable contribution limits

### 🤝 Team and Project Management
- Comprehensive team management system
- Role-based access controls
- Project portfolio management
- Dispute resolution framework
- Project categorization and discovery
- Template-based workflows

## Development

### Technical Stack

- Solidity ^0.8.13
- OpenZeppelin Contracts
- [Foundry](https://book.getfoundry.sh/) - Development Framework
- Ethereum Development Environment
  - Local: Anvil
  - Testnet: Sepolia
  - Mainnet: Ethereum

### Prerequisites

- [Foundry toolkit](https://book.getfoundry.sh/getting-started/installation)
- Node.js and npm
- Git
- Ethereum wallet with testnet ETH
- Network RPC URLs

### Configuration

The project uses Foundry with optimized settings:
- IR-based compilation enabled
- Optimizer enabled with 200 runs
- OpenZeppelin contract remappings configured

### Project Structure

```
backr/
├── src/                    # Smart contract source files
│   ├── core/              # Core protocol contracts
│   └── ux/                # User experience enhancements
├── script/                 # Deployment scripts
├── test/                  # Comprehensive test suite
├── docs/                  # Detailed documentation
└── foundry.toml          # Foundry configuration
```

### Testing

The project includes an extensive test suite covering all functionality:

```shell
# Run all tests
forge test

# Run specific test file
forge test --match-path test/Project.t.sol

# Run tests with gas reporting
forge test --gas-report

# Run tests with maximum verbosity
forge test -vvvv
```

### Deployment

1. Configure environment:
```shell
cp .env.example .env
# Edit .env with your credentials
```

2. Deploy contracts:
```shell
# Local deployment
forge script script/DeployMVP.s.sol:DeployMVPScript --rpc-url http://localhost:8545 --broadcast

# Testnet deployment
forge script script/DeployMVP.s.sol:DeployMVPScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Documentation

Comprehensive documentation is available in the `/docs` directory:

### Core Features
- [Project Management](docs/Project-Tutorial.md)
- [User Profiles](docs/UserProfile-Tutorial.md)
- [Badge System](docs/Badge-Tutorial.md)
- [Badge Marketplace](docs/BadgeMarketplace-Tutorial.md)

### Governance
- [Main Governance](docs/Governance-Tutorial.md)
- [Committee Governance](docs/CommitteeGovernance-Tutorial.md)
- [Gasless Voting](docs/GaslessVoting-Tutorial.md)
- [Proposal Templates](docs/ProposalTemplates-Tutorial.md)

### Financial Features
- [Quadratic Funding](docs/QuadraticFunding-Tutorial.md)
- [Liquidity Pool](docs/LiquidityPool-Tutorial.md)
- [Liquidity Incentives](docs/LiquidityIncentives-Tutorial.md)
- [Platform Token](docs/PlatformToken-Tutorial.md)

### Project Management
- [Project Categories](docs/ProjectCategories-Tutorial.md)
- [Project Portfolio](docs/ProjectPortfolio-Tutorial.md)
- [Project Templates](docs/ProjectTemplates-Tutorial.md)
- [Team Management](docs/TeamManagement-Tutorial.md)
- [Dispute Resolution](docs/DisputeResolution-Tutorial.md)

### Security
- [Security Controls Settings](docs/SecurityControls-Settings.md)
- [Security Controls Tutorial](docs/SecurityControls-Tutorial.md)

## Security Features

- Multi-layered security controls
- Rate limiting mechanisms
- Time-locked operations
- Emergency pause functionality
- Multi-signature requirements
- Comprehensive access controls
- Automated security checks in CI/CD

## Contributing

1. Fork the repository
2. Create your feature branch
3. Run tests and ensure they pass
4. Submit a pull request

## License

This project is licensed under the MIT License.
