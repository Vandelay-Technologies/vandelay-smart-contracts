// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vandelay Token Vesting
 * @dev Implementation of a token vesting system for employee and investor compensation
 * @author DeFi-Vandelay for Vandelay Technologies
 * @notice This contract implements a token vesting system with configurable schedules and milestones
 */

contract VandelayTokenVesting {
    // Structure for vesting schedule details
    struct VestingSchedule {
        address beneficiary;               // Address of the beneficiary
        uint256 totalAmount;               // Total amount of tokens to be vested
        uint256 releasedAmount;            // Amount of tokens already released
        uint256 startTime;                 // Time when the vesting starts
        uint256 cliffDuration;             // Duration of the cliff period
        uint256 vestingDuration;           // Duration of the vesting period
        uint256 revocable;                 // Whether the vesting schedule can be revoked
        bool revoked;                      // Whether the vesting schedule has been revoked
    }

    // Mapping from vesting schedule ID to VestingSchedule struct
    mapping(bytes32 => VestingSchedule) public vestingSchedules;
    
    // Mapping from beneficiary address to array of vesting schedule IDs
    mapping(address => bytes32[]) public beneficiarySchedules;
    
    // ERC20 token address
    address public tokenAddress;
    
    // Owner of the contract
    address public owner;
    
    // Events
    event VestingScheduleCreated(bytes32 indexed scheduleId, address indexed beneficiary, uint256 totalAmount);
    event TokensReleased(bytes32 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event VestingScheduleRevoked(bytes32 indexed scheduleId, address indexed beneficiary, uint256 unreleasedAmount);

    /**
     * @dev Constructor sets the owner of the contract and the token address
     * @param _tokenAddress The address of the ERC20 token contract
     */
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        tokenAddress = _tokenAddress;
        owner = msg.sender;
    }

    /**
     * @dev Modifier to restrict function access to the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev Modifier to check if a vesting schedule exists
     * @param _scheduleId The ID of the vesting schedule to check
     */
    modifier scheduleExists(bytes32 _scheduleId) {
        require(vestingSchedules[_scheduleId].beneficiary != address(0), "Vesting schedule does not exist");
        _;
    }

    /**
     * @dev Modifier to check if a vesting schedule is not revoked
     * @param _scheduleId The ID of the vesting schedule to check
     */
    modifier notRevoked(bytes32 _scheduleId) {
        require(!vestingSchedules[_scheduleId].revoked, "Vesting schedule has been revoked");
        _;
    }

    /**
     * @dev Creates a new vesting schedule
     * @param _beneficiary The address of the beneficiary
     * @param _totalAmount The total amount of tokens to be vested
     * @param _startTime The time when the vesting starts
     * @param _cliffDuration The duration of the cliff period
     * @param _vestingDuration The duration of the vesting period
     * @param _revocable Whether the vesting schedule can be revoked
     * @return scheduleId The ID of the created vesting schedule
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner returns (bytes32) {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_totalAmount > 0, "Total amount must be greater than 0");
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_cliffDuration <= _vestingDuration, "Cliff duration cannot exceed vesting duration");
        
        // Generate a unique ID for the vesting schedule
        bytes32 scheduleId = keccak256(abi.encodePacked(
            _beneficiary,
            _totalAmount,
            _startTime,
            _cliffDuration,
            _vestingDuration,
            _revocable,
            block.timestamp
        ));
        
        // Check if the vesting schedule already exists
        require(vestingSchedules[scheduleId].beneficiary == address(0), "Vesting schedule already exists");
        
        // Create the vesting schedule
        vestingSchedules[scheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            releasedAmount: 0,
            startTime: _startTime,
            cliffDuration: _cliffDuration,
            vestingDuration: _vestingDuration,
            revocable: _revocable,
            revoked: false
        });
        
        // Add the vesting schedule ID to the beneficiary's list
        beneficiarySchedules[_beneficiary].push(scheduleId);
        
        emit VestingScheduleCreated(scheduleId, _beneficiary, _totalAmount);
        
        return scheduleId;
    }

    /**
     * @dev Revokes a vesting schedule
     * @param _scheduleId The ID of the vesting schedule to revoke
     */
    function revokeVestingSchedule(bytes32 _scheduleId) external onlyOwner scheduleExists(_scheduleId) notRevoked(_scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(schedule.revocable, "Vesting schedule cannot be revoked");
        
        // Calculate the unreleased amount
        uint256 unreleasedAmount = schedule.totalAmount - schedule.releasedAmount;
        
        // Mark the vesting schedule as revoked
        schedule.revoked = true;
        
        emit VestingScheduleRevoked(_scheduleId, schedule.beneficiary, unreleasedAmount);
    }

    /**
     * @dev Releases vested tokens to the beneficiary
     * @param _scheduleId The ID of the vesting schedule to release tokens from
     */
    function releaseVestedTokens(bytes32 _scheduleId) external scheduleExists(_scheduleId) notRevoked(_scheduleId) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(block.timestamp >= schedule.startTime, "Vesting has not started yet");
        
        // Calculate the vested amount
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        
        // Calculate the amount to release
        uint256 amountToRelease = vestedAmount - schedule.releasedAmount;
        require(amountToRelease > 0, "No tokens to release");
        
        // Update the released amount
        schedule.releasedAmount = vestedAmount;
        
        // Transfer the tokens to the beneficiary
        (bool success, ) = tokenAddress.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                schedule.beneficiary,
                amountToRelease
            )
        );
        require(success, "Token transfer failed");
        
        emit TokensReleased(_scheduleId, schedule.beneficiary, amountToRelease);
    }

    /**
     * @dev Calculates the vested amount for a vesting schedule
     * @param _schedule The vesting schedule to calculate the vested amount for
     * @return The vested amount
     */
    function _calculateVestedAmount(VestingSchedule memory _schedule) internal view returns (uint256) {
        if (block.timestamp < _schedule.startTime + _schedule.cliffDuration) {
            return 0;
        }
        
        if (block.timestamp >= _schedule.startTime + _schedule.vestingDuration) {
            return _schedule.totalAmount;
        }
        
        uint256 timeFromStart = block.timestamp - _schedule.startTime;
        uint256 vestedAmount = (_schedule.totalAmount * timeFromStart) / _schedule.vestingDuration;
        
        return vestedAmount;
    }

    /**
     * @dev Returns the details of a vesting schedule
     * @param _scheduleId The ID of the vesting schedule to query
     * @return beneficiary The address of the beneficiary
     * @return totalAmount The total amount of tokens to be vested
     * @return releasedAmount The amount of tokens already released
     * @return startTime The time when the vesting starts
     * @return cliffDuration The duration of the cliff period
     * @return vestingDuration The duration of the vesting period
     * @return revocable Whether the vesting schedule can be revoked
     * @return revoked Whether the vesting schedule has been revoked
     */
    function getVestingScheduleDetails(bytes32 _scheduleId) external view returns (
        address beneficiary,
        uint256 totalAmount,
        uint256 releasedAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable,
        bool revoked
    ) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        return (
            schedule.beneficiary,
            schedule.totalAmount,
            schedule.releasedAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.vestingDuration,
            schedule.revocable,
            schedule.revoked
        );
    }

    /**
     * @dev Returns the vesting schedule IDs for a beneficiary
     * @param _beneficiary The address of the beneficiary
     * @return An array of vesting schedule IDs
     */
    function getBeneficiarySchedules(address _beneficiary) external view returns (bytes32[] memory) {
        return beneficiarySchedules[_beneficiary];
    }

    /**
     * @dev Returns the number of vesting schedules for a beneficiary
     * @param _beneficiary The address of the beneficiary
     * @return The number of vesting schedules
     */
    function getBeneficiaryScheduleCount(address _beneficiary) external view returns (uint256) {
        return beneficiarySchedules[_beneficiary].length;
    }

    /**
     * @dev Returns the vested amount for a vesting schedule
     * @param _scheduleId The ID of the vesting schedule to query
     * @return The vested amount
     */
    function getVestedAmount(bytes32 _scheduleId) external view scheduleExists(_scheduleId) returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        return _calculateVestedAmount(schedule);
    }

    /**
     * @dev Returns the releasable amount for a vesting schedule
     * @param _scheduleId The ID of the vesting schedule to query
     * @return The releasable amount
     */
    function getReleasableAmount(bytes32 _scheduleId) external view scheduleExists(_scheduleId) returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        if (schedule.revoked) {
            return 0;
        }
        
        uint256 vestedAmount = _calculateVestedAmount(schedule);
        return vestedAmount - schedule.releasedAmount;
    }

    /**
     * @dev Returns the vesting schedule ID for a beneficiary and index
     * @param _beneficiary The address of the beneficiary
     * @param _index The index of the vesting schedule
     * @return The vesting schedule ID
     */
    function getBeneficiaryScheduleId(address _beneficiary, uint256 _index) external view returns (bytes32) {
        require(_index < beneficiarySchedules[_beneficiary].length, "Index out of bounds");
        return beneficiarySchedules[_beneficiary][_index];
    }
} 