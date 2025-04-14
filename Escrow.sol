// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Escrow
 * @dev Implementation of a secure escrow system for marketplace transactions
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements an escrow system with dispute resolution capabilities
 */

contract VandelayEscrow {
    // Escrow agreement structure
    struct Agreement {
        address buyer;
        address seller;
        uint256 amount;
        uint256 deadline;
        bool isActive;
        bool isDisputed;
        bool isReleased;
        bool isRefunded;
        string description;
    }

    // Dispute structure
    struct Dispute {
        address disputer;
        string reason;
        uint256 timestamp;
        bool resolved;
    }

    // State variables
    uint256 public agreementCount;
    mapping(uint256 => Agreement) public agreements;
    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    // Events
    event AgreementCreated(uint256 indexed agreementId, address indexed buyer, address indexed seller, uint256 amount, string description);
    event FundsDeposited(uint256 indexed agreementId, address indexed buyer, uint256 amount);
    event FundsReleased(uint256 indexed agreementId, address indexed seller, uint256 amount);
    event DisputeRaised(uint256 indexed agreementId, address indexed disputer, string reason);
    event DisputeResolved(uint256 indexed agreementId, bool buyerWins);
    event FundsRefunded(uint256 indexed agreementId, address indexed buyer, uint256 amount);

    // Modifiers
    modifier agreementExists(uint256 _agreementId) {
        require(_agreementId < agreementCount, "VandelayEscrow: agreement does not exist");
        _;
    }

    modifier onlyParticipant(uint256 _agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        require(msg.sender == agreement.buyer || msg.sender == agreement.seller, "VandelayEscrow: not a participant");
        _;
    }

    modifier onlyBuyer(uint256 _agreementId) {
        require(msg.sender == agreements[_agreementId].buyer, "VandelayEscrow: not the buyer");
        _;
    }

    modifier onlySeller(uint256 _agreementId) {
        require(msg.sender == agreements[_agreementId].seller, "VandelayEscrow: not the seller");
        _;
    }

    modifier agreementActive(uint256 _agreementId) {
        require(agreements[_agreementId].isActive, "VandelayEscrow: agreement not active");
        _;
    }

    modifier notDisputed(uint256 _agreementId) {
        require(!agreements[_agreementId].isDisputed, "VandelayEscrow: agreement is disputed");
        _;
    }

    /**
     * @dev Creates a new escrow agreement
     * @param _seller The address of the seller
     * @param _amount The amount of ETH to be held in escrow
     * @param _deadline The deadline for the agreement in seconds
     * @param _description Description of the agreement
     * @return agreementId The ID of the created agreement
     */
    function createAgreement(
        address _seller,
        uint256 _amount,
        uint256 _deadline,
        string memory _description
    ) public returns (uint256) {
        require(_seller != address(0), "VandelayEscrow: zero address seller");
        require(_amount > 0, "VandelayEscrow: amount must be greater than 0");
        require(_deadline > block.timestamp, "VandelayEscrow: invalid deadline");
        
        uint256 agreementId = agreementCount;
        Agreement storage agreement = agreements[agreementId];
        
        agreement.buyer = msg.sender;
        agreement.seller = _seller;
        agreement.amount = _amount;
        agreement.deadline = _deadline;
        agreement.isActive = true;
        agreement.isDisputed = false;
        agreement.isReleased = false;
        agreement.isRefunded = false;
        agreement.description = _description;
        
        agreementCount++;
        
        emit AgreementCreated(agreementId, msg.sender, _seller, _amount, _description);
        return agreementId;
    }

    /**
     * @dev Deposits funds into escrow
     * @param _agreementId The ID of the agreement to deposit funds for
     */
    function depositFunds(uint256 _agreementId) public payable agreementExists(_agreementId) onlyBuyer(_agreementId) agreementActive(_agreementId) notDisputed(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        require(msg.value == agreement.amount, "VandelayEscrow: incorrect amount");
        
        emit FundsDeposited(_agreementId, msg.sender, msg.value);
    }

    /**
     * @dev Releases funds to the seller
     * @param _agreementId The ID of the agreement to release funds for
     */
    function releaseFunds(uint256 _agreementId) public agreementExists(_agreementId) onlyBuyer(_agreementId) agreementActive(_agreementId) notDisputed(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        require(address(this).balance >= agreement.amount, "VandelayEscrow: insufficient balance");
        require(!agreement.isReleased, "VandelayEscrow: funds already released");
        
        agreement.isReleased = true;
        agreement.isActive = false;
        
        (bool success, ) = agreement.seller.call{value: agreement.amount}("");
        require(success, "VandelayEscrow: transfer failed");
        
        emit FundsReleased(_agreementId, agreement.seller, agreement.amount);
    }

    /**
     * @dev Raises a dispute for the agreement
     * @param _agreementId The ID of the agreement to dispute
     * @param _reason The reason for the dispute
     */
    function raiseDispute(uint256 _agreementId, string memory _reason) public agreementExists(_agreementId) onlyParticipant(_agreementId) agreementActive(_agreementId) notDisputed(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        require(address(this).balance >= agreement.amount, "VandelayEscrow: insufficient balance");
        
        agreement.isDisputed = true;
        
        Dispute storage dispute = disputes[_agreementId];
        dispute.disputer = msg.sender;
        dispute.reason = _reason;
        dispute.timestamp = block.timestamp;
        dispute.resolved = false;
        
        emit DisputeRaised(_agreementId, msg.sender, _reason);
    }

    /**
     * @dev Resolves a dispute by voting
     * @param _agreementId The ID of the agreement to resolve
     * @param _buyerWins Whether the buyer should win the dispute
     */
    function resolveDispute(uint256 _agreementId, bool _buyerWins) public agreementExists(_agreementId) onlyParticipant(_agreementId) {
        Agreement storage agreement = agreements[_agreementId];
        require(agreement.isDisputed, "VandelayEscrow: agreement not disputed");
        require(!disputes[_agreementId].resolved, "VandelayEscrow: dispute already resolved");
        require(!hasVoted[_agreementId][msg.sender], "VandelayEscrow: already voted");
        
        hasVoted[_agreementId][msg.sender] = true;
        
        if (_buyerWins) {
            agreement.isRefunded = true;
            agreement.isActive = false;
            
            (bool success, ) = agreement.buyer.call{value: agreement.amount}("");
            require(success, "VandelayEscrow: refund transfer failed");
            
            emit FundsRefunded(_agreementId, agreement.buyer, agreement.amount);
        } else {
            agreement.isReleased = true;
            agreement.isActive = false;
            
            (bool success, ) = agreement.seller.call{value: agreement.amount}("");
            require(success, "VandelayEscrow: transfer failed");
            
            emit FundsReleased(_agreementId, agreement.seller, agreement.amount);
        }
        
        disputes[_agreementId].resolved = true;
        emit DisputeResolved(_agreementId, _buyerWins);
    }

    /**
     * @dev Returns the agreement details
     * @param _agreementId The ID of the agreement to query
     * @return buyer The address of the buyer
     * @return seller The address of the seller
     * @return amount The amount of ETH in escrow
     * @return deadline The deadline of the agreement
     * @return isActive Whether the agreement is active
     * @return isDisputed Whether the agreement is disputed
     * @return isReleased Whether the funds have been released
     * @return isRefunded Whether the funds have been refunded
     * @return description The description of the agreement
     */
    function getAgreement(uint256 _agreementId) public view returns (
        address buyer,
        address seller,
        uint256 amount,
        uint256 deadline,
        bool isActive,
        bool isDisputed,
        bool isReleased,
        bool isRefunded,
        string memory description
    ) {
        Agreement storage agreement = agreements[_agreementId];
        return (
            agreement.buyer,
            agreement.seller,
            agreement.amount,
            agreement.deadline,
            agreement.isActive,
            agreement.isDisputed,
            agreement.isReleased,
            agreement.isRefunded,
            agreement.description
        );
    }

    /**
     * @dev Returns the dispute details
     * @param _agreementId The ID of the agreement to query
     * @return disputer The address of the disputer
     * @return reason The reason for the dispute
     * @return timestamp The timestamp of the dispute
     * @return resolved Whether the dispute has been resolved
     */
    function getDispute(uint256 _agreementId) public view returns (
        address disputer,
        string memory reason,
        uint256 timestamp,
        bool resolved
    ) {
        Dispute storage dispute = disputes[_agreementId];
        return (dispute.disputer, dispute.reason, dispute.timestamp, dispute.resolved);
    }
} 