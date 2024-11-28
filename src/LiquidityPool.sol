// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./PlatformToken.sol";

/// @title LiquidityPool for Backr Platform
/// @notice Automated Market Maker (AMM) for ETH/BACKR trading
contract LiquidityPool {
    PlatformToken public token;
    
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
    
    error InsufficientLiquidity();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error InvalidK();
    error TransferFailed();
    error UnbalancedLiquidityRatios();
    error InsufficientTokenAmount();
    
    // Constructor now accepts minimum liquidity parameter
    constructor(address _token, uint256 _minimumLiquidity) {
        token = PlatformToken(_token);
        MINIMUM_LIQUIDITY = _minimumLiquidity == 0 ? 1000 : _minimumLiquidity;
    }
    
    /// @notice Add liquidity to the pool
    /// @param _tokenAmount Amount of tokens to add
    function addLiquidity(uint256 _tokenAmount) external payable {
        if (_tokenAmount == 0 || msg.value == 0) revert InsufficientInputAmount();
        
        uint256 liquidity;
        uint256 actualTokenAmount = _tokenAmount;
        
        if (totalLiquidity == 0) {
            liquidity = _sqrt(msg.value * actualTokenAmount);
            if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
            
            // Transfer tokens first
            bool success = token.transferFrom(msg.sender, address(this), actualTokenAmount);
            if (!success) revert TransferFailed();
            
            // Mint MINIMUM_LIQUIDITY to address(this)
            _mint(address(this), MINIMUM_LIQUIDITY);
            liquidity -= MINIMUM_LIQUIDITY;
            
            // Update reserves
            ethReserve = msg.value;
            tokenReserve = actualTokenAmount;
        } else {
            // Calculate required token amount based on current ratio
            actualTokenAmount = (msg.value * tokenReserve) / ethReserve;
            if (actualTokenAmount > _tokenAmount) revert InsufficientTokenAmount();
            
            // Verify ratio matches
            uint256 ethRatio = (msg.value * 1e18) / ethReserve;
            uint256 tokenRatio = (_tokenAmount * 1e18) / tokenReserve;
            if (ethRatio != tokenRatio) revert UnbalancedLiquidityRatios();
            
            // Transfer tokens
            bool success = token.transferFrom(msg.sender, address(this), actualTokenAmount);
            if (!success) revert TransferFailed();
            
            // Calculate liquidity tokens to mint
            liquidity = (msg.value * totalLiquidity) / ethReserve;
            
            // Update reserves
            ethReserve += msg.value;
            tokenReserve += actualTokenAmount;
        }
        
        // Mint liquidity tokens to provider
        _mint(msg.sender, liquidity);
        
        emit LiquidityAdded(msg.sender, msg.value, actualTokenAmount, liquidity);
    }
    
    /// @notice Remove liquidity from the pool
    /// @param _liquidity Amount of liquidity tokens to burn
    function removeLiquidity(uint256 _liquidity) external {
        if (_liquidity == 0) revert InsufficientInputAmount();
        if (_liquidity > liquidityBalance[msg.sender]) revert InsufficientLiquidity();
        
        // Calculate token amounts
        uint256 ethAmount = (_liquidity * ethReserve) / totalLiquidity;
        uint256 tokenAmount = (_liquidity * tokenReserve) / totalLiquidity;
        
        // Burn liquidity tokens first
        _burn(msg.sender, _liquidity);
        
        // Transfer assets
        bool success = token.transfer(msg.sender, tokenAmount);
        if (!success) revert TransferFailed();
        
        (bool sent,) = msg.sender.call{value: ethAmount}("");
        if (!sent) revert TransferFailed();
        
        // Update reserves
        ethReserve -= ethAmount;
        tokenReserve -= tokenAmount;
        
        emit LiquidityRemoved(msg.sender, ethAmount, tokenAmount, _liquidity);
    }
    
    /// @notice Swap ETH for tokens
    /// @param _minTokens Minimum amount of tokens to receive
    function swapETHForTokens(uint256 _minTokens) external payable {
        if (msg.value == 0) revert InsufficientInputAmount();
        if (ethReserve == 0 || tokenReserve == 0) revert InsufficientLiquidity();
        
        uint256 tokensOut = getOutputAmount(msg.value, ethReserve, tokenReserve);
        if (tokensOut < _minTokens) revert InsufficientOutputAmount();
        
        bool success = token.transfer(msg.sender, tokensOut);
        if (!success) revert TransferFailed();
        
        ethReserve += msg.value;
        tokenReserve -= tokensOut;
        
        emit TokensPurchased(msg.sender, msg.value, tokensOut);
    }
    
    /// @notice Swap tokens for ETH
    /// @param _tokenAmount Amount of tokens to swap
    /// @param _minETH Minimum amount of ETH to receive
    function swapTokensForETH(uint256 _tokenAmount, uint256 _minETH) external {
        if (_tokenAmount == 0) revert InsufficientInputAmount();
        if (ethReserve == 0 || tokenReserve == 0) revert InsufficientLiquidity();
        
        uint256 ethOut = getOutputAmount(_tokenAmount, tokenReserve, ethReserve);
        if (ethOut < _minETH) revert InsufficientOutputAmount();
        
        bool success = token.transferFrom(msg.sender, address(this), _tokenAmount);
        if (!success) revert TransferFailed();
        
        (bool sent,) = msg.sender.call{value: ethOut}("");
        if (!sent) revert TransferFailed();
        
        ethReserve -= ethOut;
        tokenReserve += _tokenAmount;
        
        emit TokensSold(msg.sender, _tokenAmount, ethOut);
    }
    
    /// @notice Calculate output amount based on x * y = k formula
    /// @param _inputAmount Amount of input token
    /// @param _inputReserve Reserve of input token
    /// @param _outputReserve Reserve of output token
    function getOutputAmount(
        uint256 _inputAmount,
        uint256 _inputReserve,
        uint256 _outputReserve
    ) public pure returns (uint256) {
        if (_inputReserve == 0 || _outputReserve == 0) revert InsufficientLiquidity();
        
        uint256 inputAmountWithFee = _getFeeAdjustedInput(_inputAmount);
        uint256 numerator = inputAmountWithFee * _outputReserve;
        uint256 denominator = (_inputReserve * FEE_DENOMINATOR) + inputAmountWithFee;
        
        return numerator / denominator;
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
        liquidityBalance[_to] += _amount;
        totalLiquidity += _amount;
    }
    
    /// @notice Internal function to burn liquidity tokens
    function _burn(address _from, uint256 _amount) internal {
        liquidityBalance[_from] -= _amount;
        totalLiquidity -= _amount;
    }
    
    /// @notice Calculate fee adjusted input amount
    /// @param _inputAmount Raw input amount before fee
    function _getFeeAdjustedInput(uint256 _inputAmount) internal pure returns (uint256) {
        return _inputAmount * (FEE_DENOMINATOR - FEE_NUMERATOR);
    }
    
    /// @notice Validate and calculate liquidity for initial deposit
    function _calculateInitialLiquidity(
        uint256 _ethAmount,
        uint256 _tokenAmount
    ) internal view returns (uint256 liquidity, uint256 actualTokenAmount) {
        if (_ethAmount == 0 || _tokenAmount == 0) revert InsufficientInputAmount();
        actualTokenAmount = _tokenAmount;
        liquidity = _sqrt(_ethAmount * actualTokenAmount);
        if (liquidity <= MINIMUM_LIQUIDITY) revert InsufficientLiquidity();
        return (liquidity, actualTokenAmount);
    }
    
    /// @notice Calculate liquidity and token amount for subsequent deposits
    function _calculateLiquidity(
        uint256 _ethAmount,
        uint256 _tokenAmount
    ) internal view returns (uint256 liquidity, uint256 actualTokenAmount) {
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
    
    receive() external payable {}
}
