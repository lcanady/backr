// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./PlatformToken.sol";
import "./LiquidityIncentives.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title LiquidityPool for Backr Platform
/// @notice Automated Market Maker (AMM) for ETH/BACKR trading
contract LiquidityPool is ReentrancyGuard, Pausable, Ownable {
    using SafeMath for uint256;

    PlatformToken public token;
    LiquidityIncentives public incentives;

    // Fee denominator (1000 = 0.3% fee)
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant FEE_NUMERATOR = 3;
    uint256 public immutable MINIMUM_LIQUIDITY;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityBalance;

    uint256 public ethReserve;
    uint256 public tokenReserve;

    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 liquidity);
    event TokensPurchased(address indexed buyer, uint256 ethIn, uint256 tokensOut);
    event TokensSold(address indexed seller, uint256 tokensIn, uint256 ethOut);
    event PoolStateChanged(uint256 newEthReserve, uint256 newTokenReserve);
    event EmergencyWithdrawal(address indexed owner, uint256 ethAmount, uint256 tokenAmount);
    event MaxSlippageUpdated(uint256 newMaxSlippage);

    error InsufficientLiquidity();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error InvalidK();
    error TransferFailed();
    error UnbalancedLiquidityRatios();
    error InsufficientTokenAmount();
    error SlippageExceeded();
    error EmergencyWithdrawalFailed();

    // Maximum allowed slippage in basis points (1000 = 10%)
    uint256 public maxSlippage = 1000;

    // Constructor now accepts minimum liquidity parameter
    constructor(address _token, uint256 _minimumLiquidity, address _incentives) {
        token = PlatformToken(_token);
        incentives = LiquidityIncentives(_incentives);
        MINIMUM_LIQUIDITY = _minimumLiquidity == 0 ? 1000 : _minimumLiquidity;
    }

    /// @notice Add liquidity to the pool
    /// @param _tokenAmount Amount of tokens to add
    function addLiquidity(uint256 _tokenAmount) external payable whenNotPaused nonReentrant {
        if (_tokenAmount == 0 || msg.value == 0) revert InsufficientInputAmount();

        uint256 liquidity;

        if (totalLiquidity == 0) {
            liquidity = _sqrt(msg.value * _tokenAmount);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();

            bool success = token.transferFrom(msg.sender, address(this), _tokenAmount);
            if (!success) revert TransferFailed();

            _mint(address(this), MINIMUM_LIQUIDITY);
            liquidity -= MINIMUM_LIQUIDITY;

            ethReserve = msg.value;
            tokenReserve = _tokenAmount;
            emit PoolStateChanged(ethReserve, tokenReserve);
        } else {
            uint256 ethOptimal = (msg.value * tokenReserve) / ethReserve;
            uint256 tokenOptimal = (_tokenAmount * ethReserve) / tokenReserve;

            if (ethOptimal > _tokenAmount) {
                ethOptimal = _tokenAmount;
                tokenOptimal = (ethOptimal * tokenReserve) / ethReserve;
            } else {
                tokenOptimal = msg.value;
            }

            bool success = token.transferFrom(msg.sender, address(this), tokenOptimal);
            if (!success) revert TransferFailed();

            liquidity = (tokenOptimal * totalLiquidity) / tokenReserve;

            ethReserve += msg.value;
            tokenReserve += tokenOptimal;
            emit PoolStateChanged(ethReserve, tokenReserve);
        }

        _mint(msg.sender, liquidity);

        // Always update user tier after adding liquidity
        incentives.updateUserTier(msg.sender, liquidityBalance[msg.sender]);

        emit LiquidityAdded(msg.sender, msg.value, _tokenAmount, liquidity);
    }

    /// @notice Remove liquidity from the pool
    /// @param _liquidity Amount of liquidity tokens to burn
    function removeLiquidity(uint256 _liquidity) external whenNotPaused nonReentrant {
        if (_liquidity == 0) revert InsufficientInputAmount();
        if (_liquidity > liquidityBalance[msg.sender]) revert InsufficientLiquidity();

        uint256 ethAmount = (_liquidity * ethReserve) / totalLiquidity;
        uint256 tokenAmount = (_liquidity * tokenReserve) / totalLiquidity;

        _burn(msg.sender, _liquidity);
        ethReserve -= ethAmount;
        tokenReserve -= tokenAmount;
        emit PoolStateChanged(ethReserve, tokenReserve);

        bool success = token.transfer(msg.sender, tokenAmount);
        if (!success) revert TransferFailed();

        (success,) = msg.sender.call{value: ethAmount}("");
        if (!success) revert TransferFailed();

        // Always update user tier after removing liquidity
        incentives.updateUserTier(msg.sender, liquidityBalance[msg.sender]);

        emit LiquidityRemoved(msg.sender, ethAmount, tokenAmount, _liquidity);
    }

    /// @notice Calculate output amount for a swap
    /// @param _inputAmount Amount of input token
    /// @param _inputReserve Reserve of input token
    /// @param _outputReserve Reserve of output token
    function getOutputAmount(uint256 _inputAmount, uint256 _inputReserve, uint256 _outputReserve)
        public
        pure
        returns (uint256)
    {
        if (_inputAmount == 0) revert InsufficientInputAmount();
        if (_inputReserve == 0 || _outputReserve == 0) revert InsufficientLiquidity();

        // First calculate output without fee
        uint256 withoutFee = (_inputAmount * _outputReserve) / (_inputReserve + _inputAmount);

        // Then apply the fee (0.3%)
        uint256 fee = (withoutFee * FEE_NUMERATOR) / FEE_DENOMINATOR;
        uint256 outputAmount = withoutFee - fee;

        if (outputAmount == 0) revert InsufficientOutputAmount();

        return outputAmount;
    }

    /// @notice Swap ETH for tokens
    /// @param _minTokens Minimum amount of tokens to receive
    function swapETHForTokens(uint256 _minTokens) external payable whenNotPaused nonReentrant {
        if (msg.value == 0) revert InsufficientInputAmount();
        if (ethReserve == 0 || tokenReserve == 0) revert InsufficientLiquidity();

        uint256 tokensOut = getOutputAmount(msg.value, ethReserve, tokenReserve);
        if (tokensOut < _minTokens) revert SlippageExceeded();

        // Store old reserves for k-value check
        uint256 oldEthReserve = ethReserve;
        uint256 oldTokenReserve = tokenReserve;

        // Update reserves
        ethReserve += msg.value;
        tokenReserve -= tokensOut;

        // Verify k is maintained or increased
        uint256 k = ethReserve * tokenReserve;
        uint256 previousK = oldEthReserve * oldTokenReserve;
        if (k < previousK) revert InvalidK();

        // Transfer tokens last to prevent reentrancy
        bool success = token.transfer(msg.sender, tokensOut);
        if (!success) revert TransferFailed();

        emit TokensPurchased(msg.sender, msg.value, tokensOut);
    }

    /// @notice Swap tokens for ETH
    /// @param _tokenAmount Amount of tokens to swap
    /// @param _minETH Minimum amount of ETH to receive
    function swapTokensForETH(uint256 _tokenAmount, uint256 _minETH) external whenNotPaused nonReentrant {
        if (_tokenAmount == 0) revert InsufficientInputAmount();
        if (ethReserve == 0 || tokenReserve == 0) revert InsufficientLiquidity();

        uint256 ethOut = getOutputAmount(_tokenAmount, tokenReserve, ethReserve);
        if (ethOut < _minETH) revert SlippageExceeded();

        // Store old reserves for k-value check
        uint256 oldEthReserve = ethReserve;
        uint256 oldTokenReserve = tokenReserve;

        // Update reserves
        tokenReserve += _tokenAmount;
        ethReserve -= ethOut;

        // Verify k is maintained or increased
        uint256 k = ethReserve * tokenReserve;
        uint256 previousK = oldEthReserve * oldTokenReserve;
        if (k < previousK) revert InvalidK();

        // Transfer tokens first
        bool success = token.transferFrom(msg.sender, address(this), _tokenAmount);
        if (!success) revert TransferFailed();

        // Transfer ETH last to prevent reentrancy
        (success,) = msg.sender.call{value: ethOut}("");
        if (!success) revert TransferFailed();

        emit TokensSold(msg.sender, _tokenAmount, ethOut);
    }

    /// @notice Get current exchange rate
    /// @return Amount of tokens per ETH
    function getExchangeRate() external view returns (uint256) {
        if (ethReserve == 0) revert InsufficientLiquidity();
        // Return tokens per ETH normalized to 18 decimals
        return (tokenReserve * 1e18) / ethReserve;
    }

    /// @notice Internal function to mint liquidity tokens
    function _mint(address _to, uint256 _amount) internal {
        liquidityBalance[_to] = liquidityBalance[_to] + _amount;
        totalLiquidity = totalLiquidity + _amount;
    }

    /// @notice Internal function to burn liquidity tokens
    function _burn(address _from, uint256 _amount) internal {
        require(liquidityBalance[_from] >= _amount, "Insufficient liquidity balance");
        liquidityBalance[_from] = liquidityBalance[_from] - _amount;
        totalLiquidity = totalLiquidity - _amount;
    }

    /// @notice Calculate fee adjusted input amount
    /// @param _inputAmount Raw input amount before fee
    function _getFeeAdjustedInput(uint256 _inputAmount) internal pure returns (uint256) {
        return _inputAmount.mul(FEE_DENOMINATOR.sub(FEE_NUMERATOR));
    }

    /// @notice Validate and calculate liquidity for initial deposit
    function _calculateInitialLiquidity(uint256 _ethAmount, uint256 _tokenAmount)
        internal
        view
        returns (uint256 liquidity, uint256 actualTokenAmount)
    {
        if (_ethAmount == 0 || _tokenAmount == 0) revert InsufficientInputAmount();
        actualTokenAmount = _tokenAmount;
        liquidity = _sqrt(_ethAmount * actualTokenAmount);
        if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
        return (liquidity, actualTokenAmount);
    }

    /// @notice Calculate liquidity and token amount for subsequent deposits
    function _calculateLiquidity(uint256 _ethAmount, uint256 _tokenAmount)
        internal
        view
        returns (uint256 liquidity, uint256 actualTokenAmount)
    {
        if (_ethAmount == 0 || _tokenAmount == 0) revert InsufficientInputAmount();

        uint256 ethRatio = (_ethAmount * 1e18) / ethReserve;
        uint256 tokenRatio = (_tokenAmount * 1e18) / tokenReserve;
        if (ethRatio != tokenRatio) revert UnbalancedLiquidityRatios();

        actualTokenAmount = (_ethAmount * tokenReserve) / ethReserve;
        if (actualTokenAmount > _tokenAmount) revert InsufficientTokenAmount();

        liquidity = (_ethAmount * totalLiquidity) / ethReserve;
        return (liquidity, actualTokenAmount);
    }

    /// @notice Internal function to calculate square root
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /// @notice Pause the contract
    /// @dev Only callable by owner
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract
    /// @dev Only callable by owner
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Set maximum allowed slippage
    /// @param _maxSlippage New maximum slippage in basis points
    function setMaxSlippage(uint256 _maxSlippage) external onlyOwner {
        maxSlippage = _maxSlippage;
        emit MaxSlippageUpdated(_maxSlippage);
    }

    /// @notice Emergency withdrawal function
    /// @dev Only callable by owner when paused
    function emergencyWithdraw() external onlyOwner whenPaused {
        uint256 ethBalance = address(this).balance;
        uint256 tokenBalance = token.balanceOf(address(this));

        // Reset reserves
        ethReserve = 0;
        tokenReserve = 0;
        totalLiquidity = 0;

        // Transfer tokens and ETH to owner
        bool success = token.transfer(msg.sender, tokenBalance);
        if (!success) revert EmergencyWithdrawalFailed();

        (success,) = msg.sender.call{value: ethBalance}("");
        if (!success) revert EmergencyWithdrawalFailed();

        emit EmergencyWithdrawal(msg.sender, ethBalance, tokenBalance);
    }

    receive() external payable {}
}
