// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay MultiSig Wallet
 * @dev Implementation of a multi-signature wallet requiring multiple approvals for transactions
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a secure multi-signature wallet with configurable approval requirements
 */

contract VandelayMultiSigWallet {
    // Events
    event Deposit(address indexed sender, uint256 amount);
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event TransactionApproved(uint256 indexed txId, address indexed approver);
    event TransactionExecuted(uint256 indexed txId, address indexed to, uint256 value, bytes data);
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event RequirementChanged(uint256 newRequirement);

    // Transaction structure
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 approvalCount;
        mapping(address => bool) approvals;
    }

    // State variables
    mapping(address => bool) public isOwner;
    uint256 public ownerCount;
    uint256 public requiredApprovals;
    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;
    
    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "VandelayMultiSig: caller is not an owner");
        _;
    }
    
    modifier txExists(uint256 _txId) {
        require(_txId < transactionCount, "VandelayMultiSig: transaction does not exist");
        _;
    }
    
    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "VandelayMultiSig: transaction already executed");
        _;
    }
    
    modifier notApproved(uint256 _txId) {
        require(!transactions[_txId].approvals[msg.sender], "VandelayMultiSig: transaction already approved by this owner");
        _;
    }

    /**
     * @dev Constructor initializes the wallet with owners and required approvals
     * @param _owners Array of initial owner addresses
     * @param _requiredApprovals Number of approvals required for transaction execution
     */
    constructor(address[] memory _owners, uint256 _requiredApprovals) {
        require(_owners.length > 0, "VandelayMultiSig: no owners provided");
        require(_requiredApprovals > 0 && _requiredApprovals <= _owners.length, "VandelayMultiSig: invalid required approvals");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "VandelayMultiSig: zero address owner");
            require(!isOwner[_owners[i]], "VandelayMultiSig: duplicate owner");
            
            isOwner[_owners[i]] = true;
            emit OwnerAdded(_owners[i]);
        }
        
        ownerCount = _owners.length;
        requiredApprovals = _requiredApprovals;
    }

    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Submits a new transaction for approval
     * @param _to Destination address
     * @param _value Amount of ETH to send
     * @param _data Additional data to send
     * @return txId The ID of the submitted transaction
     */
    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlyOwner returns (uint256) {
        require(_to != address(0), "VandelayMultiSig: zero address destination");
        
        uint256 txId = transactionCount;
        Transaction storage tx = transactions[txId];
        tx.to = _to;
        tx.value = _value;
        tx.data = _data;
        tx.executed = false;
        tx.approvalCount = 0;
        
        transactionCount++;
        
        emit TransactionSubmitted(txId, _to, _value, _data);
        return txId;
    }

    /**
     * @dev Approves a transaction
     * @param _txId The ID of the transaction to approve
     */
    function approveTransaction(uint256 _txId) public onlyOwner txExists(_txId) notExecuted(_txId) notApproved(_txId) {
        Transaction storage tx = transactions[_txId];
        tx.approvals[msg.sender] = true;
        tx.approvalCount++;
        
        emit TransactionApproved(_txId, msg.sender);
        
        if (tx.approvalCount >= requiredApprovals) {
            executeTransaction(_txId);
        }
    }

    /**
     * @dev Executes an approved transaction
     * @param _txId The ID of the transaction to execute
     */
    function executeTransaction(uint256 _txId) public onlyOwner txExists(_txId) notExecuted(_txId) {
        Transaction storage tx = transactions[_txId];
        require(tx.approvalCount >= requiredApprovals, "VandelayMultiSig: insufficient approvals");
        
        tx.executed = true;
        
        (bool success, ) = tx.to.call{value: tx.value}(tx.data);
        require(success, "VandelayMultiSig: transaction execution failed");
        
        emit TransactionExecuted(_txId, tx.to, tx.value, tx.data);
    }

    /**
     * @dev Adds a new owner to the wallet
     * @param _newOwner Address of the new owner
     */
    function addOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "VandelayMultiSig: zero address owner");
        require(!isOwner[_newOwner], "VandelayMultiSig: owner already exists");
        
        isOwner[_newOwner] = true;
        ownerCount++;
        
        emit OwnerAdded(_newOwner);
    }

    /**
     * @dev Removes an owner from the wallet
     * @param _owner Address of the owner to remove
     */
    function removeOwner(address _owner) public onlyOwner {
        require(isOwner[_owner], "VandelayMultiSig: not an owner");
        require(ownerCount > requiredApprovals, "VandelayMultiSig: cannot remove owner - would violate required approvals");
        
        isOwner[_owner] = false;
        ownerCount--;
        
        emit OwnerRemoved(_owner);
    }

    /**
     * @dev Changes the number of required approvals
     * @param _newRequiredApprovals New number of required approvals
     */
    function changeRequirement(uint256 _newRequiredApprovals) public onlyOwner {
        require(_newRequiredApprovals > 0 && _newRequiredApprovals <= ownerCount, "VandelayMultiSig: invalid required approvals");
        
        requiredApprovals = _newRequiredApprovals;
        
        emit RequirementChanged(_newRequiredApprovals);
    }

    /**
     * @dev Returns the transaction details
     * @param _txId The ID of the transaction to query
     * @return to Destination address
     * @return value Amount of ETH to send
     * @return data Additional data to send
     * @return executed Whether the transaction has been executed
     * @return approvalCount Number of approvals received
     */
    function getTransaction(uint256 _txId) public view returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 approvalCount
    ) {
        Transaction storage tx = transactions[_txId];
        return (tx.to, tx.value, tx.data, tx.executed, tx.approvalCount);
    }

    /**
     * @dev Checks if an owner has approved a transaction
     * @param _txId The ID of the transaction to query
     * @param _owner The address of the owner to query
     * @return Whether the owner has approved the transaction
     */
    function isApproved(uint256 _txId, address _owner) public view returns (bool) {
        return transactions[_txId].approvals[_owner];
    }
} 