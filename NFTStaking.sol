// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay NFT Staking
 * @dev Implementation of an NFT staking system that allows users to stake ERC721 NFTs to earn ERC20 tokens as rewards
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements an NFT staking system with configurable reward rates
 */

contract VandelayNFTStaking {
    // Structs
    struct Stake {
        uint256 tokenId;
        uint256 stakedAt;
        uint256 lastRewardCalculation;
        uint256 accumulatedRewards;
    }
    
    struct NFTCollection {
        address nftContract;
        uint256 rewardRate; // Rewards per day per NFT (in wei)
        bool isActive;
        uint256 totalStaked;
    }
    
    // State variables
    mapping(address => mapping(address => Stake)) public stakes; // user => collection => Stake
    mapping(address => NFTCollection) public nftCollections;
    mapping(address => uint256) public userStakedCount; // Total NFTs staked by user across all collections
    mapping(address => mapping(address => uint256)) public collectionStakedCount; // user => collection => count
    
    address public rewardToken;
    address public owner;
    bool public paused;
    
    // Events
    event NFTCollectionAdded(address indexed nftContract, uint256 rewardRate);
    event NFTCollectionUpdated(address indexed nftContract, uint256 newRewardRate);
    event NFTCollectionDeactivated(address indexed nftContract);
    event NFTStaked(address indexed user, address indexed nftContract, uint256 tokenId, uint256 timestamp);
    event NFTRewardsClaimed(address indexed user, address indexed nftContract, uint256 tokenId, uint256 amount);
    event NFTUnstaked(address indexed user, address indexed nftContract, uint256 tokenId, uint256 timestamp);
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
    
    modifier collectionExists(address _nftContract) {
        require(nftCollections[_nftContract].nftContract != address(0), "NFT collection not registered");
        _;
    }
    
    modifier collectionActive(address _nftContract) {
        require(nftCollections[_nftContract].isActive, "NFT collection is not active");
        _;
    }
    
    /**
     * @dev Constructor initializes the contract with the reward token address
     * @param _rewardToken The address of the ERC20 token used for rewards
     */
    constructor(address _rewardToken) {
        require(_rewardToken != address(0), "Invalid reward token address");
        rewardToken = _rewardToken;
        owner = msg.sender;
        paused = false;
    }
    
    /**
     * @dev Adds a new NFT collection for staking
     * @param _nftContract The address of the NFT contract
     * @param _rewardRate The reward rate per day per NFT (in wei)
     */
    function addNFTCollection(address _nftContract, uint256 _rewardRate) external onlyOwner {
        require(_nftContract != address(0), "Invalid NFT contract address");
        require(_rewardRate > 0, "Reward rate must be greater than 0");
        require(nftCollections[_nftContract].nftContract == address(0), "NFT collection already registered");
        
        nftCollections[_nftContract] = NFTCollection({
            nftContract: _nftContract,
            rewardRate: _rewardRate,
            isActive: true,
            totalStaked: 0
        });
        
        emit NFTCollectionAdded(_nftContract, _rewardRate);
    }
    
    /**
     * @dev Updates the reward rate for an NFT collection
     * @param _nftContract The address of the NFT contract
     * @param _newRewardRate The new reward rate per day per NFT (in wei)
     */
    function updateNFTCollection(address _nftContract, uint256 _newRewardRate) 
        external 
        onlyOwner 
        collectionExists(_nftContract) 
    {
        require(_newRewardRate > 0, "Reward rate must be greater than 0");
        
        nftCollections[_nftContract].rewardRate = _newRewardRate;
        
        emit NFTCollectionUpdated(_nftContract, _newRewardRate);
    }
    
    /**
     * @dev Deactivates an NFT collection
     * @param _nftContract The address of the NFT contract
     */
    function deactivateNFTCollection(address _nftContract) 
        external 
        onlyOwner 
        collectionExists(_nftContract) 
    {
        nftCollections[_nftContract].isActive = false;
        
        emit NFTCollectionDeactivated(_nftContract);
    }
    
    /**
     * @dev Stakes an NFT
     * @param _nftContract The address of the NFT contract
     * @param _tokenId The ID of the NFT to stake
     */
    function stakeNFT(address _nftContract, uint256 _tokenId) 
        external 
        whenNotPaused 
        collectionExists(_nftContract) 
        collectionActive(_nftContract) 
    {
        require(_isNFTOwner(_nftContract, _tokenId, msg.sender), "Not the owner of this NFT");
        require(stakes[msg.sender][_nftContract].tokenId == 0, "NFT already staked");
        
        // Transfer NFT to this contract
        _transferNFT(_nftContract, msg.sender, address(this), _tokenId);
        
        // Record the stake
        stakes[msg.sender][_nftContract] = Stake({
            tokenId: _tokenId,
            stakedAt: block.timestamp,
            lastRewardCalculation: block.timestamp,
            accumulatedRewards: 0
        });
        
        // Update counters
        userStakedCount[msg.sender]++;
        collectionStakedCount[msg.sender][_nftContract]++;
        nftCollections[_nftContract].totalStaked++;
        
        emit NFTStaked(msg.sender, _nftContract, _tokenId, block.timestamp);
    }
    
    /**
     * @dev Claims accumulated rewards for a staked NFT
     * @param _nftContract The address of the NFT contract
     * @param _tokenId The ID of the staked NFT
     */
    function claimRewards(address _nftContract, uint256 _tokenId) 
        external 
        whenNotPaused 
        collectionExists(_nftContract) 
    {
        Stake storage stake = stakes[msg.sender][_nftContract];
        require(stake.tokenId == _tokenId, "NFT not staked by this user");
        
        uint256 rewards = _calculateRewards(msg.sender, _nftContract);
        require(rewards > 0, "No rewards to claim");
        
        // Reset accumulated rewards and update last calculation time
        stake.accumulatedRewards = 0;
        stake.lastRewardCalculation = block.timestamp;
        
        // Transfer rewards
        _transferRewards(msg.sender, rewards);
        
        emit NFTRewardsClaimed(msg.sender, _nftContract, _tokenId, rewards);
    }
    
    /**
     * @dev Unstakes an NFT and claims any accumulated rewards
     * @param _nftContract The address of the NFT contract
     * @param _tokenId The ID of the staked NFT
     */
    function unstakeNFT(address _nftContract, uint256 _tokenId) 
        external 
        whenNotPaused 
        collectionExists(_nftContract) 
    {
        Stake storage stake = stakes[msg.sender][_nftContract];
        require(stake.tokenId == _tokenId, "NFT not staked by this user");
        
        // Calculate and claim any accumulated rewards
        uint256 rewards = _calculateRewards(msg.sender, _nftContract);
        if (rewards > 0) {
            stake.accumulatedRewards = 0;
            stake.lastRewardCalculation = block.timestamp;
            _transferRewards(msg.sender, rewards);
            emit NFTRewardsClaimed(msg.sender, _nftContract, _tokenId, rewards);
        }
        
        // Transfer NFT back to the user
        _transferNFT(_nftContract, address(this), msg.sender, _tokenId);
        
        // Clear the stake record
        delete stakes[msg.sender][_nftContract];
        
        // Update counters
        userStakedCount[msg.sender]--;
        collectionStakedCount[msg.sender][_nftContract]--;
        nftCollections[_nftContract].totalStaked--;
        
        emit NFTUnstaked(msg.sender, _nftContract, _tokenId, block.timestamp);
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
     * @dev Calculates the rewards accumulated for a staked NFT
     * @param _user The address of the user
     * @param _nftContract The address of the NFT contract
     * @return The amount of rewards accumulated
     */
    function _calculateRewards(address _user, address _nftContract) internal view returns (uint256) {
        Stake storage stake = stakes[_user][_nftContract];
        if (stake.tokenId == 0) {
            return 0;
        }
        
        NFTCollection storage collection = nftCollections[_nftContract];
        uint256 timeStaked = block.timestamp - stake.lastRewardCalculation;
        uint256 daysStaked = timeStaked / 1 days;
        
        // Calculate rewards based on days staked and reward rate
        uint256 newRewards = daysStaked * collection.rewardRate;
        
        // Add any previously accumulated rewards
        return stake.accumulatedRewards + newRewards;
    }
    
    /**
     * @dev Transfers rewards to a user
     * @param _user The address of the user
     * @param _amount The amount of rewards to transfer
     */
    function _transferRewards(address _user, uint256 _amount) internal {
        // This is a simplified version. In a real implementation, you would interact with the ERC20 token contract
        // to transfer tokens from the staking contract to the user.
        // For this example, we'll assume the staking contract has enough tokens to pay the rewards.
        
        // In a real implementation, you would use:
        // IERC20(rewardToken).transfer(_user, _amount);
        
        // For this example, we'll just emit an event to simulate the transfer
        // In a real implementation, you would need to ensure the contract has enough tokens to pay the rewards
    }
    
    /**
     * @dev Checks if a user owns an NFT
     * @param _nftContract The address of the NFT contract
     * @param _tokenId The ID of the NFT
     * @param _user The address of the user
     * @return True if the user owns the NFT, false otherwise
     */
    function _isNFTOwner(address _nftContract, uint256 _tokenId, address _user) internal view returns (bool) {
        // This is a simplified version. In a real implementation, you would interact with the ERC721 token contract
        // to check if the user owns the NFT.
        // For this example, we'll assume the user owns the NFT if they call the stake function.
        
        // In a real implementation, you would use:
        // return IERC721(_nftContract).ownerOf(_tokenId) == _user;
        
        return true; // Simplified for this example
    }
    
    /**
     * @dev Transfers an NFT
     * @param _nftContract The address of the NFT contract
     * @param _from The address to transfer from
     * @param _to The address to transfer to
     * @param _tokenId The ID of the NFT to transfer
     */
    function _transferNFT(address _nftContract, address _from, address _to, uint256 _tokenId) internal {
        // This is a simplified version. In a real implementation, you would interact with the ERC721 token contract
        // to transfer the NFT.
        // For this example, we'll assume the transfer is successful.
        
        // In a real implementation, you would use:
        // IERC721(_nftContract).transferFrom(_from, _to, _tokenId);
        
        // For this example, we'll just emit an event to simulate the transfer
    }
    
    /**
     * @dev Returns the stake details for a user's NFT
     * @param _user The address of the user
     * @param _nftContract The address of the NFT contract
     * @return tokenId The ID of the staked NFT
     * @return stakedAt The timestamp when the NFT was staked
     * @return lastRewardCalculation The timestamp of the last reward calculation
     * @return accumulatedRewards The accumulated rewards for the staked NFT
     */
    function getStakeDetails(address _user, address _nftContract) 
        external 
        view 
        returns (
            uint256 tokenId,
            uint256 stakedAt,
            uint256 lastRewardCalculation,
            uint256 accumulatedRewards
        ) 
    {
        Stake storage stake = stakes[_user][_nftContract];
        return (
            stake.tokenId,
            stake.stakedAt,
            stake.lastRewardCalculation,
            stake.accumulatedRewards
        );
    }
    
    /**
     * @dev Returns the pending rewards for a staked NFT
     * @param _user The address of the user
     * @param _nftContract The address of the NFT contract
     * @return The amount of pending rewards
     */
    function getPendingRewards(address _user, address _nftContract) external view returns (uint256) {
        return _calculateRewards(_user, _nftContract);
    }
    
    /**
     * @dev Returns the details of an NFT collection
     * @param _nftContract The address of the NFT contract
     * @return nftContract The address of the NFT contract
     * @return rewardRate The reward rate per day per NFT
     * @return isActive Whether the collection is active
     * @return totalStaked The total number of NFTs staked in this collection
     */
    function getNFTCollectionDetails(address _nftContract) 
        external 
        view 
        returns (
            address nftContract,
            uint256 rewardRate,
            bool isActive,
            uint256 totalStaked
        ) 
    {
        NFTCollection storage collection = nftCollections[_nftContract];
        return (
            collection.nftContract,
            collection.rewardRate,
            collection.isActive,
            collection.totalStaked
        );
    }
    
    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}
} 