// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Crowdfunding
 * @dev Implementation of a crowdfunding platform with token rewards
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a crowdfunding system with refund capabilities and token rewards
 */

contract VandelayCrowdfunding {
    // Campaign structure
    struct Campaign {
        address creator;
        string name;
        string description;
        uint256 goal;
        uint256 deadline;
        uint256 totalFunded;
        bool claimed;
        bool refunded;
        mapping(address => uint256) contributions;
    }

    // Token reward structure
    struct TokenReward {
        address tokenAddress;
        uint256 amount;
        bool distributed;
    }

    // State variables
    uint256 public campaignCount;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => TokenReward) public tokenRewards;
    mapping(uint256 => mapping(address => bool)) public hasClaimedReward;
    
    // Events
    event CampaignCreated(uint256 indexed campaignId, address indexed creator, string name, uint256 goal, uint256 deadline);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignFunded(uint256 indexed campaignId, uint256 totalFunded);
    event RewardClaimed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event CampaignClaimed(uint256 indexed campaignId, address indexed creator, uint256 amount);

    // Modifiers
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCount, "VandelayCrowdfunding: campaign does not exist");
        _;
    }

    modifier campaignActive(uint256 _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "VandelayCrowdfunding: campaign has ended");
        _;
    }

    modifier campaignEnded(uint256 _campaignId) {
        require(block.timestamp >= campaigns[_campaignId].deadline, "VandelayCrowdfunding: campaign has not ended");
        _;
    }

    modifier notRefunded(uint256 _campaignId) {
        require(!campaigns[_campaignId].refunded, "VandelayCrowdfunding: campaign has been refunded");
        _;
    }

    /**
     * @dev Creates a new crowdfunding campaign
     * @param _name Name of the campaign
     * @param _description Description of the campaign
     * @param _goal Funding goal in wei
     * @param _duration Duration of the campaign in seconds
     * @param _tokenAddress Address of the reward token (optional)
     * @param _tokenAmount Amount of tokens to distribute (optional)
     * @return campaignId The ID of the created campaign
     */
    function createCampaign(
        string memory _name,
        string memory _description,
        uint256 _goal,
        uint256 _duration,
        address _tokenAddress,
        uint256 _tokenAmount
    ) public returns (uint256) {
        require(_goal > 0, "VandelayCrowdfunding: goal must be greater than 0");
        require(_duration > 0 && _duration <= 365 days, "VandelayCrowdfunding: invalid duration");
        
        uint256 campaignId = campaignCount;
        Campaign storage campaign = campaigns[campaignId];
        
        campaign.creator = msg.sender;
        campaign.name = _name;
        campaign.description = _description;
        campaign.goal = _goal;
        campaign.deadline = block.timestamp + _duration;
        campaign.totalFunded = 0;
        campaign.claimed = false;
        campaign.refunded = false;
        
        if (_tokenAddress != address(0) && _tokenAmount > 0) {
            TokenReward storage reward = tokenRewards[campaignId];
            reward.tokenAddress = _tokenAddress;
            reward.amount = _tokenAmount;
            reward.distributed = false;
        }
        
        campaignCount++;
        
        emit CampaignCreated(campaignId, msg.sender, _name, _goal, campaign.deadline);
        return campaignId;
    }

    /**
     * @dev Contributes to a campaign
     * @param _campaignId The ID of the campaign to contribute to
     */
    function contribute(uint256 _campaignId) public payable campaignExists(_campaignId) campaignActive(_campaignId) {
        require(msg.value > 0, "VandelayCrowdfunding: contribution must be greater than 0");
        
        Campaign storage campaign = campaigns[_campaignId];
        campaign.contributions[msg.sender] += msg.value;
        campaign.totalFunded += msg.value;
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
        
        if (campaign.totalFunded >= campaign.goal) {
            emit CampaignFunded(_campaignId, campaign.totalFunded);
        }
    }

    /**
     * @dev Claims the campaign funds if the goal was reached
     * @param _campaignId The ID of the campaign to claim
     */
    function claimCampaign(uint256 _campaignId) public campaignExists(_campaignId) campaignEnded(_campaignId) notRefunded(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "VandelayCrowdfunding: only creator can claim");
        require(campaign.totalFunded >= campaign.goal, "VandelayCrowdfunding: goal not reached");
        require(!campaign.claimed, "VandelayCrowdfunding: campaign already claimed");
        
        campaign.claimed = true;
        
        (bool success, ) = campaign.creator.call{value: campaign.totalFunded}("");
        require(success, "VandelayCrowdfunding: transfer failed");
        
        emit CampaignClaimed(_campaignId, campaign.creator, campaign.totalFunded);
    }

    /**
     * @dev Claims token rewards for a successful campaign
     * @param _campaignId The ID of the campaign to claim rewards from
     */
    function claimReward(uint256 _campaignId) public campaignExists(_campaignId) campaignEnded(_campaignId) notRefunded(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        TokenReward storage reward = tokenRewards[_campaignId];
        
        require(campaign.totalFunded >= campaign.goal, "VandelayCrowdfunding: goal not reached");
        require(reward.tokenAddress != address(0), "VandelayCrowdfunding: no token rewards");
        require(!hasClaimedReward[_campaignId][msg.sender], "VandelayCrowdfunding: reward already claimed");
        require(campaign.contributions[msg.sender] > 0, "VandelayCrowdfunding: no contribution made");
        
        hasClaimedReward[_campaignId][msg.sender] = true;
        
        // Calculate reward based on contribution percentage
        uint256 contributionPercentage = (campaign.contributions[msg.sender] * 100) / campaign.totalFunded;
        uint256 rewardAmount = (reward.amount * contributionPercentage) / 100;
        
        // Transfer tokens using low-level call
        (bool success, ) = reward.tokenAddress.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                rewardAmount
            )
        );
        require(success, "VandelayCrowdfunding: token transfer failed");
        
        emit RewardClaimed(_campaignId, msg.sender, rewardAmount);
    }

    /**
     * @dev Issues refunds if the campaign goal was not reached
     * @param _campaignId The ID of the campaign to refund
     */
    function refund(uint256 _campaignId) public campaignExists(_campaignId) campaignEnded(_campaignId) notRefunded(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.totalFunded < campaign.goal, "VandelayCrowdfunding: goal was reached");
        require(campaign.contributions[msg.sender] > 0, "VandelayCrowdfunding: no contribution to refund");
        
        uint256 contribution = campaign.contributions[msg.sender];
        campaign.contributions[msg.sender] = 0;
        
        (bool success, ) = msg.sender.call{value: contribution}("");
        require(success, "VandelayCrowdfunding: refund transfer failed");
        
        emit RefundIssued(_campaignId, msg.sender, contribution);
    }

    /**
     * @dev Marks a campaign as refunded after all refunds have been issued
     * @param _campaignId The ID of the campaign to mark as refunded
     */
    function markRefunded(uint256 _campaignId) public campaignExists(_campaignId) campaignEnded(_campaignId) notRefunded(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.totalFunded < campaign.goal, "VandelayCrowdfunding: goal was reached");
        require(msg.sender == campaign.creator, "VandelayCrowdfunding: only creator can mark as refunded");
        
        campaign.refunded = true;
    }

    /**
     * @dev Returns campaign details
     * @param _campaignId The ID of the campaign to query
     * @return creator The address of the campaign creator
     * @return name The name of the campaign
     * @return description The description of the campaign
     * @return goal The funding goal
     * @return deadline The campaign deadline
     * @return totalFunded The total amount funded
     * @return claimed Whether the campaign has been claimed
     * @return refunded Whether the campaign has been refunded
     */
    function getCampaign(uint256 _campaignId) public view returns (
        address creator,
        string memory name,
        string memory description,
        uint256 goal,
        uint256 deadline,
        uint256 totalFunded,
        bool claimed,
        bool refunded
    ) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.name,
            campaign.description,
            campaign.goal,
            campaign.deadline,
            campaign.totalFunded,
            campaign.claimed,
            campaign.refunded
        );
    }

    /**
     * @dev Returns the contribution amount for a specific address
     * @param _campaignId The ID of the campaign to query
     * @param _contributor The address of the contributor
     * @return The amount contributed
     */
    function getContribution(uint256 _campaignId, address _contributor) public view returns (uint256) {
        return campaigns[_campaignId].contributions[_contributor];
    }

    /**
     * @dev Returns the token reward details for a campaign
     * @param _campaignId The ID of the campaign to query
     * @return tokenAddress The address of the reward token
     * @return amount The total amount of tokens to distribute
     * @return distributed Whether the tokens have been distributed
     */
    function getTokenReward(uint256 _campaignId) public view returns (
        address tokenAddress,
        uint256 amount,
        bool distributed
    ) {
        TokenReward storage reward = tokenRewards[_campaignId];
        return (reward.tokenAddress, reward.amount, reward.distributed);
    }
} 