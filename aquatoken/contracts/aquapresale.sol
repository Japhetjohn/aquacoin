// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AquaPresale is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC20 public aquaToken;
    uint256 public rate = 200000; // Number of tokens per ether
    uint256 public weiRaised;
    uint256 public tokensForPresale = 200000000 * 10**18;
    uint256 public tokensSold;
    uint256 public maxWeiRaised = 1000 ether;
    uint256 public constant MIN_BUY = 2 * 10**18;  // 2 Aqua Tokens
    uint256 public constant MAX_BUY = 50 * 10**18; // 50 Aqua Tokens
    uint256 public immutable presaleDeadline;
    mapping(address => uint256) public referralRewards;

    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event ReferralBonusAwarded(address indexed referrer, uint256 bonusAmount);
    event TokenAddressUpdated(address indexed oldToken, address indexed newToken);
    event MaxWeiRaisedUpdated(uint256 newMaxWeiRaised);
    event TokensForPresaleUpdated(uint256 newTokensForPresale);
    event RateUpdated(uint256 newRate);
    event TokensWithdrawn(address indexed owner, uint256 amount);
    event EtherWithdrawn(address indexed owner, uint256 amount);

    constructor(address _wallet, IERC20 _aquaToken) Ownable(_wallet) {
        require(_wallet != address(0), "Wallet address cannot be zero");
        require(address(_aquaToken) != address(0), "Token address cannot be zero");
        aquaToken = _aquaToken;
        presaleDeadline = block.timestamp + 6 weeks; // Set presale deadline to 6 weeks from deployment
    }

    // Fallback function to accept Ether
    fallback() external payable {
        buyTokens(msg.sender, address(0));
    }

    // Receive function to accept Ether
    receive() external payable {
        buyTokens(msg.sender, address(0));
    }

    function buyTokens(address beneficiary, address referrer) public payable nonReentrant whenNotPaused {
        require(block.timestamp <= presaleDeadline, "Presale has ended"); // Check deadline
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(msg.value != 0, "Wei amount cannot be zero");
        require(weiRaised.add(msg.value) <= maxWeiRaised, "Max funding cap reached");

        uint256 tokens = _getTokenAmount(msg.value);
        require(tokensSold.add(tokens) <= tokensForPresale, "Not enough tokens available");
        require(tokens >= MIN_BUY && tokens <= MAX_BUY, "Purchase amount outside limits");
        require(aquaToken.balanceOf(address(this)) >= tokens, "Insufficient token balance");

        // Update state
        weiRaised = weiRaised.add(msg.value);
        tokensSold = tokensSold.add(tokens);

        // Transfer tokens using SafeERC20
        aquaToken.safeTransfer(beneficiary, tokens);
        
        // Transfer ETH to owner using call
        (bool success, ) = payable(owner()).call{value: msg.value}("");
        require(success, "ETH transfer failed");

        emit TokensPurchased(msg.sender, beneficiary, msg.value, tokens);

        // Handle referral bonus
        if (referrer != address(0) && referrer != beneficiary) {
            uint256 bonusTokens = tokens.mul(10).div(100); // 10% bonus
            require(tokensSold.add(bonusTokens) <= tokensForPresale, "Not enough tokens available for referral bonus");
            tokensSold = tokensSold.add(bonusTokens);
            referralRewards[referrer] = referralRewards[referrer].add(bonusTokens);
            aquaToken.safeTransfer(referrer, bonusTokens);
            emit ReferralBonusAwarded(referrer, bonusTokens);
        }
    }

    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(rate);
    }

    function setRate(uint256 _rate) external onlyOwner {
        require(_rate > 0, "Rate must be greater than 0");
        emit RateUpdated(_rate);
        rate = _rate;
    }

    function withdrawTokens(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(aquaToken.balanceOf(address(this)) >= amount, "Insufficient balance");
        aquaToken.safeTransfer(owner(), amount);
        emit TokensWithdrawn(owner(), amount);
    }

    function setAquaToken(IERC20 _aquaToken) external onlyOwner {
        require(address(_aquaToken) != address(0), "Token address cannot be zero");
        emit TokenAddressUpdated(address(aquaToken), address(_aquaToken));
        aquaToken = _aquaToken;
    }

    function setTokensForPresale(uint256 _tokensForPresale) external onlyOwner {
        require(_tokensForPresale > 0, "Tokens for presale must be greater than 0");
        emit TokensForPresaleUpdated(_tokensForPresale);
        tokensForPresale = _tokensForPresale;
    }

    function setMaxWeiRaised(uint256 _maxWeiRaised) external onlyOwner {
        require(_maxWeiRaised > 0, "Max cap must be greater than 0");
        emit MaxWeiRaisedUpdated(_maxWeiRaised);
        maxWeiRaised = _maxWeiRaised;
    }

    function withdrawEther(uint256 amount) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "ETH transfer failed");
        emit EtherWithdrawn(owner(), amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // View function to check contract's token balance
    function getTokenBalance() external view returns (uint256) {
        return aquaToken.balanceOf(address(this));
    }
}