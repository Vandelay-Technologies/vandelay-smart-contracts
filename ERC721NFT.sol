// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay NFT Collection
 * @dev Implementation of the Vandelay NFT ERC721 token contract
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements the ERC721 standard with metadata support
 */

contract VandelayNFT {
    // Token metadata
    string public constant name = "Vandelay NFT Collection";
    string public constant symbol = "VNFT";
    
    // Token counter for unique IDs
    uint256 private _tokenIdCounter;
    
    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;
    
    // Mapping from owner address to token count
    mapping(address => uint256) private _balances;
    
    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;
    
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    // Mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    
    /**
     * @dev Constructor initializes the contract
     */
    constructor() {}
    
    /**
     * @dev Returns the number of tokens in owner's account
     * @param owner The address to query
     * @return The number of tokens owned by owner
     */
    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }
    
    /**
     * @dev Returns the owner of the token specified by tokenId
     * @param tokenId The ID of the token to query
     * @return The owner of the token
     */
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }
    
    /**
     * @dev Approves another address to transfer the given token ID
     * @param to The address to approve
     * @param tokenId The ID of the token to be approved
     */
    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "ERC721: approve caller is not owner nor approved for all");
        
        _approve(to, tokenId);
    }
    
    /**
     * @dev Returns the approved address for a token ID
     * @param tokenId The ID of the token to query
     * @return The approved address for the token
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }
    
    /**
     * @dev Approves or removes operator as an operator for the caller
     * @param operator The address to approve
     * @param approved The approval status
     */
    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "ERC721: approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    /**
     * @dev Returns if the operator is approved for all tokens of the owner
     * @param owner The address of the owner
     * @param operator The address of the operator
     * @return True if the operator is approved for all tokens
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    
    /**
     * @dev Transfers a token from one address to another
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }
    
    /**
     * @dev Safely transfers a token from one address to another
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }
    
    /**
     * @dev Safely transfers a token from one address to another with data
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     * @param data Additional data to pass to the receiver
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }
    
    /**
     * @dev Mints a new token
     * @param to The address to mint the token to
     * @param uri The token URI
     * @return The ID of the newly minted token
     */
    function mint(address to, string memory uri) public returns (uint256) {
        require(to != address(0), "ERC721: mint to the zero address");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
        
        return tokenId;
    }
    
    /**
     * @dev Returns the URI for a given token ID
     * @param tokenId The ID of the token to query
     * @return The URI of the token
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "ERC721: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }
    
    /**
     * @dev Internal function to set the token URI
     * @param tokenId The ID of the token
     * @param uri The URI to set
     */
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        require(_exists(tokenId), "ERC721: URI set of nonexistent token");
        _tokenURIs[tokenId] = uri;
    }
    
    /**
     * @dev Internal function to mint a new token
     * @param to The address to mint the token to
     * @param tokenId The ID of the token to mint
     */
    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");
        
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(address(0), to, tokenId);
    }
    
    /**
     * @dev Internal function to transfer a token
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");
        
        _approve(address(0), tokenId);
        
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        
        emit Transfer(from, to, tokenId);
    }
    
    /**
     * @dev Internal function to safely transfer a token
     * @param from The address to transfer from
     * @param to The address to transfer to
     * @param tokenId The ID of the token to transfer
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory /* data */) internal {
        _transfer(from, to, tokenId);
    }
    
    /**
     * @dev Internal function to approve an address
     * @param to The address to approve
     * @param tokenId The ID of the token to approve
     */
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    
    /**
     * @dev Internal function to check if an address is approved or owner
     * @param spender The address to check
     * @param tokenId The ID of the token to check
     * @return True if the address is approved or owner
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
    
    /**
     * @dev Internal function to check if a token exists
     * @param tokenId The ID of the token to check
     * @return True if the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }
}