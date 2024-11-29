// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title PlatformToken for Backr Platform
/// @notice ERC-20 token with governance and staking capabilities
contract PlatformToken is ERC20, Ownable {
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakeTimestamp;

    uint256 public constant MIN_STAKE_DURATION = 7 days;
    uint256 public constant STAKE_REWARD_RATE = 5; // 5% annual reward

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    constructor() ERC20("Backr Token", "BACKR") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals()); // 1 million tokens
    }

    /// @notice Mint new tokens (only owner)
    /// @param to Address to mint to
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Stake tokens
    /// @param amount Amount to stake
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        _transfer(msg.sender, address(this), amount);

        stakedBalance[msg.sender] += amount;
        stakeTimestamp[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    /// @notice Unstake tokens and claim rewards
    function unstake() external {
        uint256 stakedAmount = stakedBalance[msg.sender];
        require(stakedAmount > 0, "No tokens staked");
        require(block.timestamp >= stakeTimestamp[msg.sender] + MIN_STAKE_DURATION, "Minimum stake duration not met");

        uint256 reward = calculateReward(msg.sender);

        stakedBalance[msg.sender] = 0;
        stakeTimestamp[msg.sender] = 0;

        _mint(msg.sender, reward);
        _transfer(address(this), msg.sender, stakedAmount);

        emit Unstaked(msg.sender, stakedAmount, reward);
    }

    /// @notice Calculate staking reward for an address
    /// @param account Address to calculate reward for
    /// @return Reward amount
    function calculateReward(address account) public view returns (uint256) {
        if (stakedBalance[account] == 0) return 0;

        uint256 stakeDuration = block.timestamp - stakeTimestamp[account];
        if (stakeDuration < MIN_STAKE_DURATION) return 0;

        // Calculate reward: (staked amount * rate * time) / (365 days * 100)
        return (stakedBalance[account] * STAKE_REWARD_RATE * stakeDuration) / (365 days * 100);
    }

    /// @notice Get current staking info for an address
    /// @param account Address to get info for
    /// @return amount Amount staked
    /// @return since Timestamp of stake
    /// @return reward Current reward
    function getStakeInfo(address account) external view returns (uint256 amount, uint256 since, uint256 reward) {
        amount = stakedBalance[account];
        since = stakeTimestamp[account];
        reward = calculateReward(account);
    }
}
