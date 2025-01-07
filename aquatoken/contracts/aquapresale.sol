// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AquaPresale is Ownable, ReentrancyGuard {
    IERC20 public aquaToken;
    uint256 public rate = 200000; // Number of tokens per ether (1 ether = 1e18 wei)
    uint256 public weiRaised;
    uint256 public tokensForPresale = 200000000 * 10**18; // Set a specific token decimal, assuming 18 decimals
    uint256 public tokensSold;
    uint256 public constant MIN_BUY = 2 * 10**18;  // 2 Aqua Tokens
    uint256 public constant MAX_BUY = 50 * 10**18; // 50 Aqua Tokens
    uint256 public maxWeiRaised = 1000 ether; // Max Ether raised during presale

    bool public presalePaused = false; // To pause and resume presale

    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event PresalePaused();
    event PresaleResumed();

    // Constructor now passes _wallet to Ownable constructor
    constructor(address _wallet, IERC20 _aquaToken) Ownable(_wallet) {
    require(_wallet != address(0), "Wallet address cannot be zero");
    require(address(_aquaToken) != address(0), "Token address cannot be zero");

    aquaToken = _aquaToken;
}


    // Fallback function to accept Ether if sent to contract
    fallback() external payable {
        buyTokens(msg.sender);
    }

    // Receive function to accept Ether
    receive() external payable {
        buyTokens(msg.sender);
    }

    // Public function to buy tokens
    function buyTokens(address beneficiary) public payable nonReentrant {
        uint256 weiAmount = msg.value;
        require(!presalePaused, "Presale is paused");
        require(beneficiary != address(0), "Beneficiary address cannot be zero");
        require(weiAmount != 0, "Wei amount cannot be zero");
        require(weiRaised + weiAmount <= maxWeiRaised, "Max funding cap reached");

        uint256 tokens = _getTokenAmount(weiAmount);
        require(tokensSold + tokens <= tokensForPresale, "Not enough tokens available for presale");
        require(tokens >= MIN_BUY && tokens <= MAX_BUY, "Purchase amount must be between minimum and maximum buy limits");

        // Update state variables
        weiRaised += weiAmount;
        tokensSold += tokens;

        // Transfer AquaTokens to the beneficiary
        aquaToken.transfer(beneficiary, tokens);
        emit TokensPurchased(msg.sender, beneficiary, weiAmount, tokens);

        // Transfer funds to the owner
        payable(owner()).transfer(msg.value);
    }

    // Internal function to calculate the token amount for the given Wei amount
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount * rate;
    }

    // Owner can set the token rate
    function setRate(uint256 _rate) external onlyOwner {
        rate = _rate;
    }

    // Owner can withdraw unsold tokens
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount <= aquaToken.balanceOf(address(this)), "Insufficient balance in contract");
        aquaToken.transfer(owner(), amount);
    }

    // Owner can change the AquaToken address if needed
    function setAquaToken(IERC20 _aquaToken) external onlyOwner {
        require(address(_aquaToken) != address(0), "Token address cannot be zero");
        aquaToken = _aquaToken;
    }

    // Owner can set the number of tokens for presale
    function setTokensForPresale(uint256 _tokensForPresale) external onlyOwner {
        require(_tokensForPresale > 0, "Tokens for presale must be greater than 0");
        tokensForPresale = _tokensForPresale;
    }

    // Owner can set the maximum Ether amount to be raised during presale
    function setMaxWeiRaised(uint256 _maxWeiRaised) external onlyOwner {
        require(_maxWeiRaised > 0, "Max cap must be greater than 0");
        maxWeiRaised = _maxWeiRaised;
    }

    // Owner can pause the presale
    function pausePresale() external onlyOwner {
        presalePaused = true;
        emit PresalePaused();
    }

    // Owner can resume the presale
    function resumePresale() external onlyOwner {
        presalePaused = false;
        emit PresaleResumed();
    }

    // Owner can withdraw any Ether from the contract
    function withdrawEther(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance in contract");
        payable(owner()).transfer(amount);
    }
}