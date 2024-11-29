// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./PlatformToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "forge-std/console.sol";

/// @title LiquidityIncentives for Backr Platform
/// @notice Manages liquidity tiers, flash loans, and yield farming
contract LiquidityIncentives is ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;

    PlatformToken public token;
    address public liquidityPool;

    // Tier thresholds and multipliers
    struct Tier {
        uint256 minLiquidity; // Minimum liquidity required for tier
        uint256 rewardMultiplier; // Reward multiplier in basis points (100 = 1x)
        uint256 flashLoanFee; // Fee in basis points
        bool enabled; // Whether the tier is active
    }

    // Yield farming pool info
    struct Pool {
        uint256 totalStaked; // Total tokens staked in this pool
        uint256 rewardRate; // Tokens per second
        uint256 lastUpdateTime; // Last time rewards were updated
        uint256 rewardPerToken; // Accumulated rewards per token
        bool active; // Whether the pool is accepting stakes
    }

    // User staking info
    struct UserInfo {
        uint256 stakedAmount; // Amount of tokens staked
        uint256 rewardDebt; // Reward debt for reward calculation
        uint256 lastRewardPerToken; // Last reward per token for user
    }

    // Flash loan state
    struct FlashLoan {
        address borrower;
        uint256 amount;
        uint256 fee;
        bool active;
    }

    // Mappings
    mapping(uint256 => Tier) public tiers;
    mapping(address => uint256) public userTiers;
    mapping(uint256 => Pool) public pools;
    mapping(address => mapping(uint256 => UserInfo)) public userPoolInfo;
    mapping(address => FlashLoan) public flashLoans;

    // Constants
    uint256 public constant FLASH_LOAN_FEE_DENOMINATOR = 10000; // 100% = 10000
    uint256 public constant MAX_POOLS = 5;
    uint256 public constant REWARD_PRECISION = 1e18;

    // Events
    event TierUpdated(uint256 tierId, uint256 minLiquidity, uint256 rewardMultiplier, uint256 flashLoanFee);
    event UserTierChanged(address indexed user, uint256 oldTier, uint256 newTier);
    event PoolCreated(uint256 poolId, uint256 rewardRate);
    event Staked(address indexed user, uint256 poolId, uint256 amount);
    event Unstaked(address indexed user, uint256 poolId, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 poolId, uint256 amount);
    event FlashLoanTaken(address indexed borrower, uint256 amount, uint256 fee);
    event FlashLoanRepaid(address indexed borrower, uint256 amount, uint256 fee);

    // Errors
    error InvalidTier();
    error InvalidPool();
    error PoolNotActive();
    error InsufficientBalance();
    error FlashLoanActive();
    error UnauthorizedFlashLoan();
    error FlashLoanRepaymentFailed();

    constructor(address _token, address _liquidityPool) {
        token = PlatformToken(_token);
        liquidityPool = _liquidityPool;

        // Initialize tiers with lower thresholds
        tiers[1] = Tier({
            minLiquidity: 1000e15, // 0.001 tokens
            rewardMultiplier: 100, // 1x
            flashLoanFee: 30, // 0.3%
            enabled: true
        });

        tiers[2] = Tier({
            minLiquidity: 10000e15, // 0.01 tokens
            rewardMultiplier: 150, // 1.5x
            flashLoanFee: 25, // 0.25%
            enabled: true
        });

        tiers[3] = Tier({
            minLiquidity: 100000e15, // 0.1 tokens
            rewardMultiplier: 200, // 2x
            flashLoanFee: 20, // 0.2%
            enabled: true
        });
    }

    /// @notice Update user's tier based on their liquidity
    /// @param _user Address of the user
    /// @param _liquidity Current liquidity provided by user
    function updateUserTier(address _user, uint256 _liquidity) external {
        require(msg.sender == liquidityPool, "Only liquidity pool can update tiers");

        uint256 oldTier = userTiers[_user];
        uint256 newTier = 0;

        // Determine tier based on liquidity thresholds
        if (_liquidity >= tiers[1].minLiquidity && tiers[1].enabled) {
            newTier = 1;
            if (_liquidity >= tiers[2].minLiquidity && tiers[2].enabled) {
                newTier = 2;
                if (_liquidity >= tiers[3].minLiquidity && tiers[3].enabled) {
                    newTier = 3;
                }
            }
        }

        // Update user's tier
        userTiers[_user] = newTier;

        if (newTier != oldTier) {
            emit UserTierChanged(_user, oldTier, newTier);
        }
    }

    // Only for testing purposes
    function manualUpdateUserTier(address _user, uint256 _liquidity) external onlyOwner {
        uint256 oldTier = userTiers[_user];
        uint256 newTier = 0;

        // Determine tier based on liquidity thresholds
        if (_liquidity >= tiers[1].minLiquidity && tiers[1].enabled) {
            newTier = 1;
            if (_liquidity >= tiers[2].minLiquidity && tiers[2].enabled) {
                newTier = 2;
                if (_liquidity >= tiers[3].minLiquidity && tiers[3].enabled) {
                    newTier = 3;
                }
            }
        }

        // Update user's tier
        userTiers[_user] = newTier;

        if (newTier != oldTier) {
            emit UserTierChanged(_user, oldTier, newTier);
        }
    }

    /// @notice Create a new yield farming pool
    /// @param _poolId Pool identifier
    /// @param _rewardRate Tokens per second for rewards
    function createPool(uint256 _poolId, uint256 _rewardRate) external onlyOwner {
        require(_poolId > 0 && _poolId <= MAX_POOLS, "Invalid pool ID");
        require(!pools[_poolId].active, "Pool already exists");

        pools[_poolId] = Pool({
            totalStaked: 0,
            rewardRate: _rewardRate,
            lastUpdateTime: block.timestamp,
            rewardPerToken: 0,
            active: true
        });

        emit PoolCreated(_poolId, _rewardRate);
    }

    /// @notice Stake tokens in a yield farming pool
    /// @param _poolId Pool to stake in
    /// @param _amount Amount to stake
    function stake(uint256 _poolId, uint256 _amount) external nonReentrant whenNotPaused {
        Pool storage pool = pools[_poolId];
        if (!pool.active) revert PoolNotActive();

        // Update pool rewards
        updatePoolRewards(_poolId);

        // Transfer tokens to this contract
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert InsufficientBalance();

        // Update user info
        UserInfo storage user = userPoolInfo[msg.sender][_poolId];

        // Calculate pending rewards
        uint256 pendingRewards = 0;
        if (user.stakedAmount > 0) {
            pendingRewards = (user.stakedAmount * (pool.rewardPerToken - user.lastRewardPerToken)) / REWARD_PRECISION;
        }

        // Update user stake and rewards
        user.stakedAmount += _amount;
        user.rewardDebt += pendingRewards;
        user.lastRewardPerToken = pool.rewardPerToken;

        // Update pool total staked
        pool.totalStaked += _amount;

        emit Staked(msg.sender, _poolId, _amount);
    }

    /// @notice Unstake tokens from a yield farming pool
    /// @param _poolId Pool to unstake from
    /// @param _amount Amount to unstake
    function unstake(uint256 _poolId, uint256 _amount) external nonReentrant {
        UserInfo storage user = userPoolInfo[msg.sender][_poolId];
        require(user.stakedAmount >= _amount, "Insufficient staked amount");

        // Update pool rewards
        updatePoolRewards(_poolId);

        // Calculate rewards
        Pool storage pool = pools[_poolId];
        uint256 pendingRewards =
            user.stakedAmount.mul(pool.rewardPerToken.sub(user.lastRewardPerToken)).div(REWARD_PRECISION);
        user.rewardDebt = user.rewardDebt.add(pendingRewards);

        // Update state
        user.stakedAmount = user.stakedAmount.sub(_amount);
        user.lastRewardPerToken = pool.rewardPerToken;
        pool.totalStaked = pool.totalStaked.sub(_amount);

        // Transfer tokens back to user
        bool success = token.transfer(msg.sender, _amount);
        require(success, "Transfer failed");

        emit Unstaked(msg.sender, _poolId, _amount);
    }

    /// @notice Claim rewards from a yield farming pool
    /// @param _poolId Pool to claim rewards from
    function claimRewards(uint256 _poolId) external nonReentrant {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userPoolInfo[msg.sender][_poolId];

        // Update pool rewards before calculation
        updatePoolRewards(_poolId);

        // Calculate user's pending rewards
        uint256 pendingRewards = calculatePendingRewards(_poolId, msg.sender);

        // Ensure we have enough tokens to pay rewards
        require(token.balanceOf(address(this)) >= pendingRewards, "Insufficient reward balance");

        // Transfer rewards
        if (pendingRewards > 0) {
            token.transfer(msg.sender, pendingRewards);

            // Update user's reward debt
            user.rewardDebt = user.stakedAmount.mul(pool.rewardPerToken).div(REWARD_PRECISION);

            emit RewardsClaimed(msg.sender, _poolId, pendingRewards);
        }
    }

    /// @notice Update pool rewards
    /// @param _poolId Pool to update
    function updatePoolRewards(uint256 _poolId) internal {
        Pool storage pool = pools[_poolId];
        if (pool.totalStaked == 0) {
            pool.lastUpdateTime = block.timestamp;
            return;
        }

        // Calculate time elapsed since last update
        uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;

        // Calculate rewards for the elapsed time
        uint256 totalRewards = timeElapsed * pool.rewardRate;

        // Prevent division by zero and ensure precision
        if (pool.totalStaked > 0) {
            // Use SafeMath for additional safety
            uint256 newRewardPerToken =
                pool.rewardPerToken.add(totalRewards.mul(REWARD_PRECISION).div(pool.totalStaked));

            pool.rewardPerToken = newRewardPerToken;
        }

        pool.lastUpdateTime = block.timestamp;
    }

    /// @notice Calculate pending rewards for a user in a pool
    /// @param _poolId Pool to calculate rewards for
    /// @param _user User to calculate rewards for
    function calculatePendingRewards(uint256 _poolId, address _user) public view returns (uint256) {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userPoolInfo[_user][_poolId];

        if (user.stakedAmount == 0) return 0;

        // Calculate pending rewards based on staked amount and reward per token
        uint256 pendingRewards = user.stakedAmount.mul(pool.rewardPerToken.sub(user.lastRewardPerToken)).div(
            REWARD_PRECISION
        ).add(user.rewardDebt);

        return pendingRewards;
    }

    /// @notice Execute a flash loan
    /// @param _amount Amount to borrow
    /// @param _params Arbitrary data to pass to the callback
    function flashLoan(uint256 _amount, bytes calldata _params) external nonReentrant {
        // Check if a flash loan is already active for this borrower
        if (flashLoans[msg.sender].active) {
            revert FlashLoanActive();
        }

        // Check user's tier and validate flash loan
        uint256 userTier = userTiers[msg.sender];

        // Require at least tier 1 for flash loans
        if (userTier == 0) {
            revert UnauthorizedFlashLoan();
        }

        // Calculate flash loan fee based on tier
        Tier memory tier = tiers[userTier];
        uint256 flashLoanFee = (_amount * tier.flashLoanFee) / FLASH_LOAN_FEE_DENOMINATOR;

        // Ensure contract has enough tokens for the loan
        uint256 contractBalance = token.balanceOf(address(this));

        if (contractBalance < _amount) {
            revert InsufficientBalance();
        }

        // Record flash loan details
        flashLoans[msg.sender] = FlashLoan({borrower: msg.sender, amount: _amount, fee: flashLoanFee, active: true});

        // Store initial balance for repayment calculation
        uint256 initialBalance = token.balanceOf(address(this));

        // Transfer tokens to borrower
        require(token.transfer(msg.sender, _amount), "Transfer failed");

        // Attempt flash loan operation
        try IFlashLoanReceiver(msg.sender).executeOperation(_amount, flashLoanFee, _params) {
            // Calculate required repayment (loan amount + fee)
            uint256 requiredRepayment = _amount + flashLoanFee;

            // Calculate actual repayment
            uint256 finalBalance = token.balanceOf(address(this));

            // The repaid amount is the difference between final and initial balance
            if (finalBalance <= initialBalance - _amount) {
                revert FlashLoanRepaymentFailed();
            }

            uint256 repaidAmount = finalBalance - (initialBalance - _amount);
            if (repaidAmount < requiredRepayment) {
                revert FlashLoanRepaymentFailed();
            }

            // Emit events
            emit FlashLoanTaken(msg.sender, _amount, flashLoanFee);
            emit FlashLoanRepaid(msg.sender, _amount, flashLoanFee);
        } catch {
            // Revert if flash loan operation fails
            revert UnauthorizedFlashLoan();
        }

        // Always reset flash loan state
        delete flashLoans[msg.sender];
    }

    /// @notice Update tier parameters
    /// @param _tierId Tier to update
    /// @param _minLiquidity New minimum liquidity requirement
    /// @param _rewardMultiplier New reward multiplier
    /// @param _flashLoanFee New flash loan fee
    /// @param _enabled Whether the tier should be enabled
    function updateTier(
        uint256 _tierId,
        uint256 _minLiquidity,
        uint256 _rewardMultiplier,
        uint256 _flashLoanFee,
        bool _enabled
    ) external onlyOwner {
        require(_tierId > 0 && _tierId <= 3, "Invalid tier ID");

        tiers[_tierId] = Tier({
            minLiquidity: _minLiquidity,
            rewardMultiplier: _rewardMultiplier,
            flashLoanFee: _flashLoanFee,
            enabled: _enabled
        });

        emit TierUpdated(_tierId, _minLiquidity, _rewardMultiplier, _flashLoanFee);
    }

    /// @notice Update liquidity pool address
    /// @param _liquidityPool New liquidity pool address
    function updateLiquidityPool(address _liquidityPool) external onlyOwner {
        require(_liquidityPool != address(0), "Invalid address");
        liquidityPool = _liquidityPool;
    }

    /// @notice Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}

/// @title Flash Loan Receiver Interface
/// @notice Interface for contracts that want to receive flash loans
interface IFlashLoanReceiver {
    function executeOperation(uint256 amount, uint256 fee, bytes calldata data) external;
}
