// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay DAO Governance
 * @dev Implementation of a decentralized autonomous organization governance system
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a DAO governance system with proposal creation, voting, and execution
 */

contract VandelayDAO {
    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool cancelled;
        mapping(address => bool) hasVoted;
        mapping(address => bool) votedFor;
    }

    // State variables
    address public governanceToken;
    uint256 public proposalCount;
    uint256 public minimumVotingPeriod;
    uint256 public minimumProposalDelay;
    uint256 public quorumPercentage;
    uint256 public proposalThreshold;
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public lastProposalTimestamp;
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description, uint256 startTime, uint256 endTime);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event GovernanceParametersUpdated(uint256 minimumVotingPeriod, uint256 minimumProposalDelay, uint256 quorumPercentage, uint256 proposalThreshold);

    // Modifiers
    modifier onlyTokenHolder() {
        require(getTokenBalance(msg.sender) > 0, "VandelayDAO: not a token holder");
        _;
    }

    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "VandelayDAO: invalid proposal");
        require(!proposals[_proposalId].cancelled, "VandelayDAO: proposal cancelled");
        require(!proposals[_proposalId].executed, "VandelayDAO: proposal already executed");
        _;
    }

    /**
     * @dev Constructor initializes the DAO governance contract
     * @param _governanceToken The address of the governance token
     * @param _minimumVotingPeriod The minimum voting period in seconds
     * @param _minimumProposalDelay The minimum delay between proposals in seconds
     * @param _quorumPercentage The minimum percentage of total supply required for a valid vote
     * @param _proposalThreshold The minimum token amount required to create a proposal
     */
    constructor(
        address _governanceToken,
        uint256 _minimumVotingPeriod,
        uint256 _minimumProposalDelay,
        uint256 _quorumPercentage,
        uint256 _proposalThreshold
    ) {
        require(_governanceToken != address(0), "VandelayDAO: zero address token");
        require(_minimumVotingPeriod > 0, "VandelayDAO: zero voting period");
        require(_minimumProposalDelay > 0, "VandelayDAO: zero proposal delay");
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "VandelayDAO: invalid quorum percentage");
        
        governanceToken = _governanceToken;
        minimumVotingPeriod = _minimumVotingPeriod;
        minimumProposalDelay = _minimumProposalDelay;
        quorumPercentage = _quorumPercentage;
        proposalThreshold = _proposalThreshold;
    }

    /**
     * @dev Creates a new proposal
     * @param _description The description of the proposal
     * @return The ID of the created proposal
     */
    function createProposal(string memory _description) public onlyTokenHolder returns (uint256) {
        require(getTokenBalance(msg.sender) >= proposalThreshold, "VandelayDAO: insufficient tokens for proposal");
        require(block.timestamp >= lastProposalTimestamp[msg.sender] + minimumProposalDelay, "VandelayDAO: proposal delay not met");
        
        uint256 proposalId = ++proposalCount;
        Proposal storage proposal = proposals[proposalId];
        
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = _description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + minimumVotingPeriod;
        proposal.executed = false;
        proposal.cancelled = false;
        
        lastProposalTimestamp[msg.sender] = block.timestamp;
        
        emit ProposalCreated(proposalId, msg.sender, _description, proposal.startTime, proposal.endTime);
        
        return proposalId;
    }

    /**
     * @dev Casts a vote on a proposal
     * @param _proposalId The ID of the proposal
     * @param _support Whether to support the proposal
     */
    function castVote(uint256 _proposalId, bool _support) public onlyTokenHolder validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "VandelayDAO: voting period not active");
        require(!proposal.hasVoted[msg.sender], "VandelayDAO: already voted");
        
        uint256 votes = getTokenBalance(msg.sender);
        require(votes > 0, "VandelayDAO: no voting power");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.votedFor[msg.sender] = _support;
        
        if (_support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support, votes);
    }

    /**
     * @dev Executes a proposal if it has passed
     * @param _proposalId The ID of the proposal
     */
    function executeProposal(uint256 _proposalId) public validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.endTime, "VandelayDAO: voting period not ended");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalSupply = getTotalSupply();
        require(totalVotes >= (totalSupply * quorumPercentage) / 100, "VandelayDAO: quorum not met");
        require(proposal.forVotes > proposal.againstVotes, "VandelayDAO: proposal not passed");
        
        proposal.executed = true;
        
        emit ProposalExecuted(_proposalId);
    }

    /**
     * @dev Cancels a proposal
     * @param _proposalId The ID of the proposal
     */
    function cancelProposal(uint256 _proposalId) public validProposal(_proposalId) {
        Proposal storage proposal = proposals[_proposalId];
        require(msg.sender == proposal.proposer, "VandelayDAO: not the proposer");
        require(block.timestamp < proposal.endTime, "VandelayDAO: voting period ended");
        
        proposal.cancelled = true;
        
        emit ProposalCancelled(_proposalId);
    }

    /**
     * @dev Updates the governance parameters
     * @param _minimumVotingPeriod The new minimum voting period
     * @param _minimumProposalDelay The new minimum proposal delay
     * @param _quorumPercentage The new quorum percentage
     * @param _proposalThreshold The new proposal threshold
     */
    function updateGovernanceParameters(
        uint256 _minimumVotingPeriod,
        uint256 _minimumProposalDelay,
        uint256 _quorumPercentage,
        uint256 _proposalThreshold
    ) public {
        require(_minimumVotingPeriod > 0, "VandelayDAO: zero voting period");
        require(_minimumProposalDelay > 0, "VandelayDAO: zero proposal delay");
        require(_quorumPercentage > 0 && _quorumPercentage <= 100, "VandelayDAO: invalid quorum percentage");
        
        minimumVotingPeriod = _minimumVotingPeriod;
        minimumProposalDelay = _minimumProposalDelay;
        quorumPercentage = _quorumPercentage;
        proposalThreshold = _proposalThreshold;
        
        emit GovernanceParametersUpdated(_minimumVotingPeriod, _minimumProposalDelay, _quorumPercentage, _proposalThreshold);
    }

    /**
     * @dev Returns the token balance of an address
     * @param _account The address to check
     * @return The token balance
     */
    function getTokenBalance(address _account) public view returns (uint256) {
        (bool success, bytes memory data) = governanceToken.staticcall(
            abi.encodeWithSignature("balanceOf(address)", _account)
        );
        require(success, "VandelayDAO: balance check failed");
        return abi.decode(data, (uint256));
    }

    /**
     * @dev Returns the total token supply
     * @return The total supply
     */
    function getTotalSupply() public view returns (uint256) {
        (bool success, bytes memory data) = governanceToken.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );
        require(success, "VandelayDAO: supply check failed");
        return abi.decode(data, (uint256));
    }

    /**
     * @dev Returns the details of a proposal
     * @param _proposalId The ID of the proposal
     * @return proposer The address of the proposer
     * @return description The description of the proposal
     * @return startTime The start time of the voting period
     * @return endTime The end time of the voting period
     * @return forVotes The number of votes for the proposal
     * @return againstVotes The number of votes against the proposal
     * @return executed Whether the proposal has been executed
     * @return cancelled Whether the proposal has been cancelled
     */
    function getProposal(uint256 _proposalId) public view returns (
        address proposer,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed,
        bool cancelled
    ) {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.proposer,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.executed,
            proposal.cancelled
        );
    }

    /**
     * @dev Returns whether an address has voted on a proposal
     * @param _proposalId The ID of the proposal
     * @param _voter The address of the voter
     * @return Whether the address has voted
     */
    function hasVoted(uint256 _proposalId, address _voter) public view returns (bool) {
        return proposals[_proposalId].hasVoted[_voter];
    }

    /**
     * @dev Returns how an address voted on a proposal
     * @param _proposalId The ID of the proposal
     * @param _voter The address of the voter
     * @return Whether the address voted for the proposal
     */
    function votedFor(uint256 _proposalId, address _voter) public view returns (bool) {
        return proposals[_proposalId].votedFor[_voter];
    }
} 