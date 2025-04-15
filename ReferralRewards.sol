// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Referral Rewards
 * @dev Implementation of a referral rewards system that tracks user referrals and distributes rewards
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a referral system with configurable reward structures
 */

contract VandelayReferralRewards {
    // Structs
    struct Referral {
        address referrer;
        uint256 timestamp;
        bool hasStaked;
        bool hasPurchased;
        uint256 stakingAmount;
        uint256 purchaseAmount;
    }

    struct RewardTier {
        uint256 stakingThreshold;
        uint256 purchaseThreshold;
        uint256 referrerReward;
        uint256 refereeReward;
    }

    // State variables
    mapping(address => Referral) public referrals;
    mapping(address => bool) public hasReferred;
    mapping(address => uint256) public referralCount;
    mapping(address => uint256) public totalRewardsEarned;
    
    RewardTier[] public rewardTiers;
    address public owner;
    bool public paused;
    
    // Events
    event ReferralRegistered(address indexed referrer, address indexed referee, uint256 timestamp);
    event RewardTierAdded(uint256 stakingThreshold, uint256 purchaseThreshold, uint256 referrerReward, uint256 refereeReward);
    event RewardsDistributed(address indexed referrer, address indexed referee, uint256 referrerReward, uint256 refereeReward, string reason);
    event StakingRecorded(address indexed referee, uint256 amount);
    event PurchaseRecorded(address indexed referee, uint256 amount);
    event ContractPaused(bool status);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    /**
     * @dev Constructor initializes the contract with default reward tiers
     */
    constructor() {
        owner = msg.sender;
        paused = false;
        
        // Add default reward tiers
        addRewardTier(1 ether, 0.5 ether, 0.1 ether, 0.05 ether); // Tier 1
        addRewardTier(5 ether, 2 ether, 0.5 ether, 0.25 ether);  // Tier 2
        addRewardTier(10 ether, 5 ether, 1 ether, 0.5 ether);    // Tier 3
    }
    
    /**
     * @dev Registers a new referral
     * @param _referee The address of the person being referred
     * @param _referrer The address of the referrer
     */
    function registerReferral(address _referee, address _referrer) external whenNotPaused {
        require(_referee != address(0), "Invalid referee address");
        require(_referrer != address(0), "Invalid referrer address");
        require(_referee != _referrer, "Cannot refer yourself");
        require(referrals[_referee].referrer == address(0), "Referee already has a referrer");
        
        referrals[_referee] = Referral({
            referrer: _referrer,
            timestamp: block.timestamp,
            hasStaked: false,
            hasPurchased: false,
            stakingAmount: 0,
            purchaseAmount: 0
        });
        
        referralCount[_referrer]++;
        hasReferred[_referrer] = true;
        
        emit ReferralRegistered(_referrer, _referee, block.timestamp);
    }
    
    /**
     * @dev Records a staking action for a referee
     * @param _referee The address of the referee who staked
     * @param _amount The amount staked
     */
    function recordStaking(address _referee, uint256 _amount) external whenNotPaused {
        require(_referee != address(0), "Invalid referee address");
        require(_amount > 0, "Staking amount must be greater than 0");
        require(referrals[_referee].referrer != address(0), "Referee not registered");
        require(!referrals[_referee].hasStaked, "Staking already recorded");
        
        referrals[_referee].hasStaked = true;
        referrals[_referee].stakingAmount = _amount;
        
        emit StakingRecorded(_referee, _amount);
        
        // Check if rewards should be distributed
        _checkAndDistributeRewards(_referee);
    }
    
    /**
     * @dev Records a purchase action for a referee
     * @param _referee The address of the referee who made a purchase
     * @param _amount The amount purchased
     */
    function recordPurchase(address _referee, uint256 _amount) external whenNotPaused {
        require(_referee != address(0), "Invalid referee address");
        require(_amount > 0, "Purchase amount must be greater than 0");
        require(referrals[_referee].referrer != address(0), "Referee not registered");
        require(!referrals[_referee].hasPurchased, "Purchase already recorded");
        
        referrals[_referee].hasPurchased = true;
        referrals[_referee].purchaseAmount = _amount;
        
        emit PurchaseRecorded(_referee, _amount);
        
        // Check if rewards should be distributed
        _checkAndDistributeRewards(_referee);
    }
    
    /**
     * @dev Adds a new reward tier
     * @param _stakingThreshold The staking threshold for this tier
     * @param _purchaseThreshold The purchase threshold for this tier
     * @param _referrerReward The reward for the referrer
     * @param _refereeReward The reward for the referee
     */
    function addRewardTier(
        uint256 _stakingThreshold,
        uint256 _purchaseThreshold,
        uint256 _referrerReward,
        uint256 _refereeReward
    ) public onlyOwner {
        require(_stakingThreshold > 0 || _purchaseThreshold > 0, "At least one threshold must be greater than 0");
        require(_referrerReward > 0 || _refereeReward > 0, "At least one reward must be greater than 0");
        
        rewardTiers.push(RewardTier({
            stakingThreshold: _stakingThreshold,
            purchaseThreshold: _purchaseThreshold,
            referrerReward: _referrerReward,
            refereeReward: _refereeReward
        }));
        
        emit RewardTierAdded(_stakingThreshold, _purchaseThreshold, _referrerReward, _refereeReward);
    }
    
    /**
     * @dev Pauses or unpauses the contract
     * @param _paused The new paused status
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit ContractPaused(_paused);
    }
    
    /**
     * @dev Transfers ownership of the contract
     * @param _newOwner The address of the new owner
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be the zero address");
        owner = _newOwner;
    }
    
    /**
     * @dev Checks if rewards should be distributed and distributes them if conditions are met
     * @param _referee The address of the referee
     */
    function _checkAndDistributeRewards(address _referee) internal {
        Referral storage referral = referrals[_referee];
        address referrer = referral.referrer;
        
        // Skip if rewards already distributed
        if (referral.hasStaked && referral.hasPurchased) {
            return;
        }
        
        // Find the highest tier that the referee qualifies for
        uint256 highestTierIndex = 0;
        bool qualifiesForAnyTier = false;
        
        for (uint256 i = 0; i < rewardTiers.length; i++) {
            bool qualifiesForTier = true;
            
            // Check staking threshold if staking is recorded
            if (referral.hasStaked && referral.stakingAmount < rewardTiers[i].stakingThreshold) {
                qualifiesForTier = false;
            }
            
            // Check purchase threshold if purchase is recorded
            if (referral.hasPurchased && referral.purchaseAmount < rewardTiers[i].purchaseThreshold) {
                qualifiesForTier = false;
            }
            
            // If qualifies for this tier and it's higher than the current highest, update
            if (qualifiesForTier && i >= highestTierIndex) {
                highestTierIndex = i;
                qualifiesForAnyTier = true;
            }
        }
        
        // Distribute rewards if qualifies for any tier
        if (qualifiesForAnyTier) {
            RewardTier storage tier = rewardTiers[highestTierIndex];
            
            // Distribute referrer reward
            if (tier.referrerReward > 0) {
                totalRewardsEarned[referrer] += tier.referrerReward;
                (bool success, ) = referrer.call{value: tier.referrerReward}("");
                require(success, "Transfer to referrer failed");
            }
            
            // Distribute referee reward
            if (tier.refereeReward > 0) {
                totalRewardsEarned[_referee] += tier.refereeReward;
                (bool success, ) = _referee.call{value: tier.refereeReward}("");
                require(success, "Transfer to referee failed");
            }
            
            emit RewardsDistributed(
                referrer,
                _referee,
                tier.referrerReward,
                tier.refereeReward,
                referral.hasStaked ? "staking" : "purchase"
            );
        }
    }
    
    /**
     * @dev Returns the number of reward tiers
     * @return The number of reward tiers
     */
    function getRewardTierCount() external view returns (uint256) {
        return rewardTiers.length;
    }
    
    /**
     * @dev Returns the details of a specific reward tier
     * @param _index The index of the reward tier
     * @return stakingThreshold The staking threshold for this tier
     * @return purchaseThreshold The purchase threshold for this tier
     * @return referrerReward The reward for the referrer
     * @return refereeReward The reward for the referee
     */
    function getRewardTier(uint256 _index) external view returns (
        uint256 stakingThreshold,
        uint256 purchaseThreshold,
        uint256 referrerReward,
        uint256 refereeReward
    ) {
        require(_index < rewardTiers.length, "Index out of bounds");
        RewardTier storage tier = rewardTiers[_index];
        return (
            tier.stakingThreshold,
            tier.purchaseThreshold,
            tier.referrerReward,
            tier.refereeReward
        );
    }
    
    /**
     * @dev Returns the referral details for a specific address
     * @param _referee The address of the referee
     * @return referrer The address of the referrer
     * @return timestamp The timestamp when the referral was registered
     * @return hasStaked Whether the referee has staked
     * @return hasPurchased Whether the referee has purchased
     * @return stakingAmount The amount staked by the referee
     * @return purchaseAmount The amount purchased by the referee
     */
    function getReferralDetails(address _referee) external view returns (
        address referrer,
        uint256 timestamp,
        bool hasStaked,
        bool hasPurchased,
        uint256 stakingAmount,
        uint256 purchaseAmount
    ) {
        Referral storage referral = referrals[_referee];
        return (
            referral.referrer,
            referral.timestamp,
            referral.hasStaked,
            referral.hasPurchased,
            referral.stakingAmount,
            referral.purchaseAmount
        );
    }
    
    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}
} 