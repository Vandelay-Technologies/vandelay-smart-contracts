// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Governance Token Staking
 * @dev Implementation of a governance token staking system with rewards distribution
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract allows users to stake governance tokens and earn rewards based on their stake
 */

contract VandelayGovernanceTokenStaking {
    // Structs
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardCalculation;
        uint256 accumulatedRewards;
    }

    struct RewardPeriod {
        uint256 startTime;
        uint256 endTime;
        uint256 rewardPerToken;
        uint256 totalStaked;
        bool isActive;
    }

    // State variables
    address public governanceToken;
    uint256 public minStakeAmount;
    uint256 public minStakeDuration;
    uint256 public rewardRate; // Rewards per token per second (in wei)
    uint256 public totalStaked;
    uint256 public currentRewardPeriodId;
    
    mapping(address => Stake) public stakes;
    mapping(uint256 => RewardPeriod) public rewardPeriods;
    mapping(address => uint256) public userRewardPeriods;
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event RewardPeriodStarted(uint256 indexed periodId, uint256 startTime, uint256 rewardRate);
    event RewardPeriodEnded(uint256 indexed periodId, uint256 endTime, uint256 totalRewards);
    event MinStakeAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event MinStakeDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    /**
     * @dev Constructor initializes the staking contract
     * @param _governanceToken The address of the governance token
     * @param _minStakeAmount The minimum amount of tokens required to stake
     * @param _minStakeDuration The minimum duration for staking in seconds
     * @param _rewardRate The initial reward rate per token per second
     */
    constructor(
        address _governanceToken,
        uint256 _minStakeAmount,
        uint256 _minStakeDuration,
        uint256 _rewardRate
    ) {
        require(_governanceToken != address(0), "Invalid governance token address");
        require(_minStakeAmount > 0, "Min stake amount must be greater than 0");
        require(_minStakeDuration > 0, "Min stake duration must be greater than 0");
        require(_rewardRate > 0, "Reward rate must be greater than 0");
        
        governanceToken = _governanceToken;
        minStakeAmount = _minStakeAmount;
        minStakeDuration = _minStakeDuration;
        rewardRate = _rewardRate;
        
        // Start the first reward period
        _startNewRewardPeriod();
    }

    /**
     * @dev Stakes governance tokens
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external {
        require(amount >= minStakeAmount, "Stake amount below minimum");
        
        // Transfer tokens from user to this contract
        (bool success, ) = governanceToken.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(success, "Token transfer failed");
        
        // Update user's stake
        Stake storage userStake = stakes[msg.sender];
        
        // If user already has a stake, calculate and accumulate rewards
        if (userStake.amount > 0) {
            _calculateRewards(msg.sender);
        } else {
            userStake.startTime = block.timestamp;
            userStake.lastRewardCalculation = block.timestamp;
        }
        
        userStake.amount += amount;
        totalStaked += amount;
        
        // Update current reward period
        RewardPeriod storage currentPeriod = rewardPeriods[currentRewardPeriodId];
        currentPeriod.totalStaked = totalStaked;
        
        emit Staked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Unstakes governance tokens and claims rewards
     * @param amount The amount of tokens to unstake
     */
    function unstake(uint256 amount) external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient stake amount");
        require(block.timestamp >= userStake.startTime + minStakeDuration, "Stake duration not met");
        
        // Calculate and accumulate rewards
        _calculateRewards(msg.sender);
        
        // Update user's stake
        userStake.amount -= amount;
        totalStaked -= amount;
        
        // Update current reward period
        RewardPeriod storage currentPeriod = rewardPeriods[currentRewardPeriodId];
        currentPeriod.totalStaked = totalStaked;
        
        // Transfer tokens back to user
        (bool success, ) = governanceToken.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount)
        );
        require(success, "Token transfer failed");
        
        emit Unstaked(msg.sender, amount, userStake.accumulatedRewards, block.timestamp);
    }

    /**
     * @dev Claims accumulated rewards
     */
    function claimRewards() external {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake found");
        
        // Calculate and accumulate rewards
        _calculateRewards(msg.sender);
        
        uint256 rewards = userStake.accumulatedRewards;
        require(rewards > 0, "No rewards to claim");
        
        userStake.accumulatedRewards = 0;
        
        // Transfer rewards to user
        (bool success, ) = msg.sender.call{value: rewards}("");
        require(success, "Reward transfer failed");
        
        emit RewardsClaimed(msg.sender, rewards, block.timestamp);
    }

    /**
     * @dev Starts a new reward period
     */
    function startNewRewardPeriod() external {
        _startNewRewardPeriod();
    }

    /**
     * @dev Updates the minimum stake amount
     * @param newMinStakeAmount The new minimum stake amount
     */
    function updateMinStakeAmount(uint256 newMinStakeAmount) external {
        require(newMinStakeAmount > 0, "Min stake amount must be greater than 0");
        uint256 oldMinStakeAmount = minStakeAmount;
        minStakeAmount = newMinStakeAmount;
        emit MinStakeAmountUpdated(oldMinStakeAmount, newMinStakeAmount);
    }

    /**
     * @dev Updates the minimum stake duration
     * @param newMinStakeDuration The new minimum stake duration in seconds
     */
    function updateMinStakeDuration(uint256 newMinStakeDuration) external {
        require(newMinStakeDuration > 0, "Min stake duration must be greater than 0");
        uint256 oldMinStakeDuration = minStakeDuration;
        minStakeDuration = newMinStakeDuration;
        emit MinStakeDurationUpdated(oldMinStakeDuration, newMinStakeDuration);
    }

    /**
     * @dev Updates the reward rate
     * @param newRewardRate The new reward rate per token per second
     */
    function updateRewardRate(uint256 newRewardRate) external {
        require(newRewardRate > 0, "Reward rate must be greater than 0");
        uint256 oldRewardRate = rewardRate;
        rewardRate = newRewardRate;
        emit RewardRateUpdated(oldRewardRate, newRewardRate);
    }

    /**
     * @dev Returns the current stake information for a user
     * @param user The address of the user
     * @return amount The amount of tokens staked
     * @return startTime The timestamp when the stake started
     * @return lastRewardCalculation The timestamp of the last reward calculation
     * @return accumulatedRewards The accumulated rewards
     */
    function getUserStake(address user) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 lastRewardCalculation,
        uint256 accumulatedRewards
    ) {
        Stake storage userStake = stakes[user];
        return (
            userStake.amount,
            userStake.startTime,
            userStake.lastRewardCalculation,
            userStake.accumulatedRewards
        );
    }

    /**
     * @dev Returns the current reward period information
     * @param periodId The ID of the reward period
     * @return startTime The timestamp when the period started
     * @return endTime The timestamp when the period ended (0 if active)
     * @return rewardPerToken The reward per token for the period
     * @return totalStaked The total amount staked during the period
     * @return isActive Whether the period is active
     */
    function getRewardPeriod(uint256 periodId) external view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 rewardPerToken,
        uint256 totalStaked,
        bool isActive
    ) {
        RewardPeriod storage period = rewardPeriods[periodId];
        return (
            period.startTime,
            period.endTime,
            period.rewardPerToken,
            period.totalStaked,
            period.isActive
        );
    }

    /**
     * @dev Calculates and accumulates rewards for a user
     * @param user The address of the user
     */
    function _calculateRewards(address user) internal {
        Stake storage userStake = stakes[user];
        if (userStake.amount == 0) return;
        
        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - userStake.lastRewardCalculation;
        
        if (timeElapsed > 0) {
            uint256 rewards = (userStake.amount * rewardRate * timeElapsed) / 1e18;
            userStake.accumulatedRewards += rewards;
        }
        
        userStake.lastRewardCalculation = currentTime;
    }

    /**
     * @dev Starts a new reward period
     */
    function _startNewRewardPeriod() internal {
        // End current period if it exists and is active
        if (rewardPeriods[currentRewardPeriodId].isActive) {
            rewardPeriods[currentRewardPeriodId].isActive = false;
            rewardPeriods[currentRewardPeriodId].endTime = block.timestamp;
            emit RewardPeriodEnded(
                currentRewardPeriodId,
                block.timestamp,
                rewardPeriods[currentRewardPeriodId].rewardPerToken
            );
        }
        
        // Start new period
        currentRewardPeriodId++;
        rewardPeriods[currentRewardPeriodId] = RewardPeriod({
            startTime: block.timestamp,
            endTime: 0,
            rewardPerToken: rewardRate,
            totalStaked: totalStaked,
            isActive: true
        });
        
        emit RewardPeriodStarted(currentRewardPeriodId, block.timestamp, rewardRate);
    }

    /**
     * @dev Allows the contract to receive ETH for rewards
     */
    receive() external payable {}
} 