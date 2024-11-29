// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title PlatformToken for Backr Platform
/// @notice ERC-20 token with governance and staking capabilities
contract PlatformToken {
    string public constant name = "Backr Token";
    string public constant symbol = "BACKR";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakeTimestamp;

    address public owner;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18; // 1 million tokens
    uint256 public constant MIN_STAKE_DURATION = 7 days;
    uint256 public constant STAKE_REWARD_RATE = 5; // 5% annual reward

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);

    error InsufficientBalance();
    error InsufficientAllowance();
    error StakingDurationNotMet();
    error InsufficientStakedBalance();
    error TransferFailed();

    constructor() {
        owner = msg.sender;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /// @notice Transfer tokens to a specified address
    /// @param _to The address to transfer to
    /// @param _value The amount to be transferred
    function transfer(address _to, uint256 _value) public returns (bool) {
        if (balanceOf[msg.sender] < _value) revert InsufficientBalance();

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @notice Approve the passed address to spend the specified amount of tokens
    /// @param _spender The address which will spend the funds
    /// @param _value The amount of tokens to be spent
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /// @notice Transfer tokens from one address to another
    /// @param _from address The address which you want to send tokens from
    /// @param _to address The address which you want to transfer to
    /// @param _value uint256 the amount of tokens to be transferred
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        if (balanceOf[_from] < _value) revert InsufficientBalance();
        if (allowance[_from][msg.sender] < _value) revert InsufficientAllowance();

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    /// @notice Stake tokens for rewards
    /// @param _amount The amount of tokens to stake
    function stake(uint256 _amount) public {
        if (balanceOf[msg.sender] < _amount) revert InsufficientBalance();

        balanceOf[msg.sender] -= _amount;
        stakedBalance[msg.sender] += _amount;
        stakeTimestamp[msg.sender] = block.timestamp;

        emit Staked(msg.sender, _amount);
    }

    /// @notice Unstake tokens and claim rewards
    function unstake() public {
        uint256 stakedAmount = stakedBalance[msg.sender];
        if (stakedAmount == 0) revert InsufficientStakedBalance();
        if (block.timestamp < stakeTimestamp[msg.sender] + MIN_STAKE_DURATION) {
            revert StakingDurationNotMet();
        }

        uint256 reward = calculateReward(msg.sender);
        stakedBalance[msg.sender] = 0;

        // Transfer staked amount and reward
        balanceOf[msg.sender] += stakedAmount + reward;
        _mint(msg.sender, reward);

        emit Unstaked(msg.sender, stakedAmount, reward);
    }

    /// @notice Calculate staking reward for an address
    /// @param _staker Address of the staker
    /// @return Reward amount
    function calculateReward(address _staker) public view returns (uint256) {
        uint256 stakingDuration = block.timestamp - stakeTimestamp[_staker];
        if (stakingDuration < MIN_STAKE_DURATION) return 0;

        // Calculate reward based on 5% annual rate
        uint256 reward = (stakedBalance[_staker] * STAKE_REWARD_RATE) / 100;

        // Adjust reward based on staking duration
        if (stakingDuration < 365 days) {
            reward = (reward * stakingDuration) / (365 days);
        }

        return reward;
    }

    /// @notice Internal function to mint new tokens
    /// @param _to Address to mint tokens to
    /// @param _amount Amount of tokens to mint
    function _mint(address _to, uint256 _amount) internal {
        totalSupply += _amount;
        balanceOf[_to] += _amount;
        emit Transfer(address(0), _to, _amount);
    }
}
