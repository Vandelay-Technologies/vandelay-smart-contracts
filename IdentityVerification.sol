// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Identity Verification
 * @dev Implementation of a contract for managing on-chain identity attestations
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract allows for verification of user identities through attestations
 */

contract IdentityVerification {
    // Structs
    struct Attestation {
        address attester;
        address subject;
        string attestationType;
        uint256 timestamp;
        bool isValid;
    }
    
    struct Attester {
        bool isAuthorized;
        string name;
        uint256 attestationCount;
    }
    
    // State variables
    address public owner;
    mapping(address => Attester) public attesters;
    mapping(address => mapping(string => Attestation)) public attestations;
    mapping(address => string[]) public subjectAttestationTypes;
    mapping(string => bool) public validAttestationTypes;
    
    // Events
    event AttestationAdded(address indexed subject, string attestationType, address indexed attester);
    event AttestationRevoked(address indexed subject, string attestationType, address indexed attester);
    event AttesterAdded(address indexed attester, string name);
    event AttesterRemoved(address indexed attester);
    event AttestationTypeAdded(string attestationType);
    event AttestationTypeRemoved(string attestationType);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Errors
    error UnauthorizedAttester();
    error InvalidAttestationType();
    error AttestationAlreadyExists();
    error AttestationDoesNotExist();
    error AttestationAlreadyRevoked();
    error AttesterAlreadyExists();
    error AttesterDoesNotExist();
    error AttestationTypeAlreadyExists();
    error AttestationTypeDoesNotExist();
    error OwnableUnauthorizedAccount(address account);
    
    /**
     * @dev Constructor that initializes the contract with an owner
     * @param initialOwner The address of the initial owner
     */
    constructor(address initialOwner) {
        require(initialOwner != address(0), "Invalid initial owner address");
        owner = initialOwner;
        
        // Add some default attestation types
        validAttestationTypes["KYC_VERIFIED"] = true;
        validAttestationTypes["HUMAN_VERIFIED"] = true;
        validAttestationTypes["LOCATION_VERIFIED"] = true;
    }
    
    /**
     * @dev Modifier to restrict function access to the owner
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }
    
    /**
     * @dev Modifier to restrict function access to authorized attesters
     */
    modifier onlyAttester() {
        if (!attesters[msg.sender].isAuthorized) revert UnauthorizedAttester();
        _;
    }
    
    /**
     * @dev Adds a new attestation for a subject
     * @param subject The address of the subject being attested
     * @param attestationType The type of attestation
     */
    function addAttestation(address subject, string memory attestationType) external onlyAttester {
        if (!validAttestationTypes[attestationType]) revert InvalidAttestationType();
        if (attestations[subject][attestationType].isValid) revert AttestationAlreadyExists();
        
        Attestation memory newAttestation = Attestation({
            attester: msg.sender,
            subject: subject,
            attestationType: attestationType,
            timestamp: block.timestamp,
            isValid: true
        });
        
        attestations[subject][attestationType] = newAttestation;
        subjectAttestationTypes[subject].push(attestationType);
        attesters[msg.sender].attestationCount++;
        
        emit AttestationAdded(subject, attestationType, msg.sender);
    }
    
    /**
     * @dev Revokes an existing attestation for a subject
     * @param subject The address of the subject whose attestation is being revoked
     * @param attestationType The type of attestation to revoke
     */
    function revokeAttestation(address subject, string memory attestationType) external onlyAttester {
        if (!attestations[subject][attestationType].isValid) revert AttestationDoesNotExist();
        if (attestations[subject][attestationType].attester != msg.sender && msg.sender != owner) revert UnauthorizedAttester();
        
        attestations[subject][attestationType].isValid = false;
        
        emit AttestationRevoked(subject, attestationType, msg.sender);
    }
    
    /**
     * @dev Adds a new attester to the system
     * @param attester The address of the new attester
     * @param name The name of the attester
     */
    function addAttester(address attester, string memory name) external onlyOwner {
        if (attesters[attester].isAuthorized) revert AttesterAlreadyExists();
        
        attesters[attester] = Attester({
            isAuthorized: true,
            name: name,
            attestationCount: 0
        });
        
        emit AttesterAdded(attester, name);
    }
    
    /**
     * @dev Removes an attester from the system
     * @param attester The address of the attester to remove
     */
    function removeAttester(address attester) external onlyOwner {
        if (!attesters[attester].isAuthorized) revert AttesterDoesNotExist();
        
        attesters[attester].isAuthorized = false;
        
        emit AttesterRemoved(attester);
    }
    
    /**
     * @dev Adds a new attestation type to the system
     * @param attestationType The new attestation type to add
     */
    function addAttestationType(string memory attestationType) external onlyOwner {
        if (validAttestationTypes[attestationType]) revert AttestationTypeAlreadyExists();
        
        validAttestationTypes[attestationType] = true;
        
        emit AttestationTypeAdded(attestationType);
    }
    
    /**
     * @dev Removes an attestation type from the system
     * @param attestationType The attestation type to remove
     */
    function removeAttestationType(string memory attestationType) external onlyOwner {
        if (!validAttestationTypes[attestationType]) revert AttestationTypeDoesNotExist();
        
        validAttestationTypes[attestationType] = false;
        
        emit AttestationTypeRemoved(attestationType);
    }
    
    /**
     * @dev Checks if a subject has a valid attestation of a specific type
     * @param subject The address of the subject to check
     * @param attestationType The type of attestation to check
     * @return A boolean indicating whether the attestation is valid
     */
    function hasValidAttestation(address subject, string memory attestationType) external view returns (bool) {
        return attestations[subject][attestationType].isValid;
    }
    
    /**
     * @dev Gets all attestation types for a subject
     * @param subject The address of the subject
     * @return An array of attestation types
     */
    function getSubjectAttestationTypes(address subject) external view returns (string[] memory) {
        return subjectAttestationTypes[subject];
    }
    
    /**
     * @dev Gets the details of a specific attestation
     * @param subject The address of the subject
     * @param attestationType The type of attestation
     * @return The attestation details
     */
    function getAttestation(address subject, string memory attestationType) external view returns (Attestation memory) {
        return attestations[subject][attestationType];
    }
    
    /**
     * @dev Transfers ownership of the contract to a new owner
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    /**
     * @dev Checks if the caller is the owner
     */
    function _checkOwner() internal view {
        if (owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }
    
    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {}
} 