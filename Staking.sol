// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Staking
 * @dev Implementation of a token staking system with reward distribution
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a staking system with flexible reward rates and withdrawal periods
 */

contract VandelayStaking {
    // Staking position structure
    struct Position {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardCalculation;
        uint256 accumulatedRewards;
    }

    // Reward rate structure
    struct RewardRate {
        uint256 rate; // Rewards per second per token staked (in wei)
        uint256 startTime;
        uint256 endTime;
    }

    // State variables
    address public stakingToken;
    uint256 public totalStaked;
    uint256 public currentRewardRate;
    uint256 public rewardRateUpdateTime;
    uint256 public minimumStakingPeriod;
    uint256 public maximumStakingPeriod;
    
    mapping(address => Position) public positions;
    mapping(address => uint256) public unclaimedRewards;
    RewardRate[] public rewardRates;
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event RewardRateUpdated(uint256 newRate, uint256 timestamp);
    event StakingPeriodUpdated(uint256 minimum, uint256 maximum);

    // Modifiers
    modifier hasStaked() {
        require(positions[msg.sender].amount > 0, "VandelayStaking: no staking position");
        _;
    }

    modifier validStakingPeriod(uint256 _period) {
        require(_period >= minimumStakingPeriod && _period <= maximumStakingPeriod, "VandelayStaking: invalid staking period");
        _;
    }

    /**
     * @dev Constructor initializes the staking contract
     * @param _stakingToken The address of the token to be staked
     * @param _minimumPeriod The minimum staking period in seconds
     * @param _maximumPeriod The maximum staking period in seconds
     * @param _initialRewardRate The initial reward rate per second per token
     */
    constructor(
        address _stakingToken,
        uint256 _minimumPeriod,
        uint256 _maximumPeriod,
        uint256 _initialRewardRate
    ) {
        require(_stakingToken != address(0), "VandelayStaking: zero address token");
        require(_minimumPeriod > 0, "VandelayStaking: zero minimum period");
        require(_maximumPeriod >= _minimumPeriod, "VandelayStaking: maximum period less than minimum");
        
        stakingToken = _stakingToken;
        minimumStakingPeriod = _minimumPeriod;
        maximumStakingPeriod = _maximumPeriod;
        currentRewardRate = _initialRewardRate;
        rewardRateUpdateTime = block.timestamp;
        
        rewardRates.push(RewardRate({
            rate: _initialRewardRate,
            startTime: block.timestamp,
            endTime: type(uint256).max
        }));
    }

    /**
     * @dev Stakes tokens into the contract
     * @param _amount The amount of tokens to stake
     */
    function stake(uint256 _amount) public {
        require(_amount > 0, "VandelayStaking: zero amount");
        
        // Transfer tokens from user to contract
        (bool success, ) = stakingToken.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                _amount
            )
        );
        require(success, "VandelayStaking: token transfer failed");
        
        // Update position
        Position storage position = positions[msg.sender];
        if (position.amount > 0) {
            // Calculate and accumulate rewards for existing position
            uint256 rewards = calculateRewards(msg.sender);
            position.accumulatedRewards += rewards;
            position.lastRewardCalculation = block.timestamp;
        } else {
            // Initialize new position
            position.startTime = block.timestamp;
            position.lastRewardCalculation = block.timestamp;
            position.accumulatedRewards = 0;
        }
        
        position.amount += _amount;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount, block.timestamp);
    }

    /**
     * @dev Withdraws staked tokens
     * @param _amount The amount of tokens to withdraw
     */
    function withdraw(uint256 _amount) public hasStaked {
        Position storage position = positions[msg.sender];
        require(_amount <= position.amount, "VandelayStaking: insufficient balance");
        require(block.timestamp >= position.startTime + minimumStakingPeriod, "VandelayStaking: minimum staking period not met");
        
        // Calculate and accumulate rewards
        uint256 rewards = calculateRewards(msg.sender);
        position.accumulatedRewards += rewards;
        position.lastRewardCalculation = block.timestamp;
        
        // Update position
        position.amount -= _amount;
        totalStaked -= _amount;
        
        // Transfer tokens back to user
        (bool success, ) = stakingToken.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                _amount
            )
        );
        require(success, "VandelayStaking: token transfer failed");
        
        emit Withdrawn(msg.sender, _amount, block.timestamp);
    }

    /**
     * @dev Claims accumulated rewards
     */
    function claimRewards() public hasStaked {
        Position storage position = positions[msg.sender];
        uint256 rewards = calculateRewards(msg.sender);
        position.accumulatedRewards += rewards;
        position.lastRewardCalculation = block.timestamp;
        
        require(position.accumulatedRewards > 0, "VandelayStaking: no rewards to claim");
        
        uint256 rewardAmount = position.accumulatedRewards;
        position.accumulatedRewards = 0;
        
        // Transfer rewards to user
        (bool success, ) = stakingToken.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                rewardAmount
            )
        );
        require(success, "VandelayStaking: reward transfer failed");
        
        emit RewardsClaimed(msg.sender, rewardAmount, block.timestamp);
    }

    /**
     * @dev Updates the reward rate
     * @param _newRate The new reward rate per second per token
     */
    function updateRewardRate(uint256 _newRate) public {
        require(_newRate != currentRewardRate, "VandelayStaking: same reward rate");
        
        // Update the end time of the current rate
        rewardRates[rewardRates.length - 1].endTime = block.timestamp;
        
        // Add new rate
        rewardRates.push(RewardRate({
            rate: _newRate,
            startTime: block.timestamp,
            endTime: type(uint256).max
        }));
        
        currentRewardRate = _newRate;
        rewardRateUpdateTime = block.timestamp;
        
        emit RewardRateUpdated(_newRate, block.timestamp);
    }

    /**
     * @dev Updates the staking period limits
     * @param _minimumPeriod The new minimum staking period in seconds
     * @param _maximumPeriod The new maximum staking period in seconds
     */
    function updateStakingPeriod(uint256 _minimumPeriod, uint256 _maximumPeriod) public {
        require(_minimumPeriod > 0, "VandelayStaking: zero minimum period");
        require(_maximumPeriod >= _minimumPeriod, "VandelayStaking: maximum period less than minimum");
        
        minimumStakingPeriod = _minimumPeriod;
        maximumStakingPeriod = _maximumPeriod;
        
        emit StakingPeriodUpdated(_minimumPeriod, _maximumPeriod);
    }

    /**
     * @dev Calculates the rewards for a given user
     * @param _user The address of the user
     * @return The amount of rewards
     */
    function calculateRewards(address _user) public view returns (uint256) {
        Position storage position = positions[_user];
        if (position.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - position.lastRewardCalculation;
        return (position.amount * currentRewardRate * timeElapsed) / 1e18;
    }

    /**
     * @dev Returns the staking position details for a user
     * @param _user The address of the user
     * @return amount The amount of tokens staked
     * @return startTime The start time of the position
     * @return lastRewardCalculation The last time rewards were calculated
     * @return accumulatedRewards The accumulated rewards
     */
    function getPosition(address _user) public view returns (
        uint256 amount,
        uint256 startTime,
        uint256 lastRewardCalculation,
        uint256 accumulatedRewards
    ) {
        Position storage position = positions[_user];
        return (
            position.amount,
            position.startTime,
            position.lastRewardCalculation,
            position.accumulatedRewards
        );
    }

    /**
     * @dev Returns the current reward rate details
     * @return rate The current reward rate
     * @return startTime The start time of the current rate
     * @return endTime The end time of the current rate
     */
    function getCurrentRewardRate() public view returns (
        uint256 rate,
        uint256 startTime,
        uint256 endTime
    ) {
        RewardRate storage currentRate = rewardRates[rewardRates.length - 1];
        return (currentRate.rate, currentRate.startTime, currentRate.endTime);
    }

    /**
     * @dev Returns the total number of reward rates
     * @return The number of reward rates
     */
    function getRewardRateCount() public view returns (uint256) {
        return rewardRates.length;
    }

    /**
     * @dev Returns the details of a specific reward rate
     * @param _index The index of the reward rate
     * @return rate The reward rate
     * @return startTime The start time of the rate
     * @return endTime The end time of the rate
     */
    function getRewardRate(uint256 _index) public view returns (
        uint256 rate,
        uint256 startTime,
        uint256 endTime
    ) {
        require(_index < rewardRates.length, "VandelayStaking: index out of bounds");
        RewardRate storage rewardRate = rewardRates[_index];
        return (rewardRate.rate, rewardRate.startTime, rewardRate.endTime);
    }
} 