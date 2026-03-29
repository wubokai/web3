// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Like {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MiniTokenVesting {
    struct VestingSchedule{
        uint256 totalAmount;
        uint256 released;
        uint256 start;
        uint256 cliffDuration;
        uint256 duration;
        bool initialized;
    }

    address public owner;
    IERC20Like public immutable token;
    uint256 public totalAllocated;

    mapping(address => VestingSchedule) public vestings;

    error NotOwner();
    error ZeroAddress();
    error InvalidAmount();
    error InvalidDuration();
    error VestingAlreadyExists();
    error VestingNotFound();
    error NoTokensToRelease();
    error TransferFailed();
    error InsufficientFunding();

    event VestingCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint64 start,
        uint64 cliffDuration,
        uint64 duration
    );

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(address _token){
        if(_token == address(0)) revert ZeroAddress();
        token = IERC20Like(_token);
        owner = msg.sender;
    }

    modifier onlyOwner(){
        if(msg.sender != owner) revert NotOwner();
        _;
    }

    function createVesting(
        address beneficiary,
        uint256 totalAmount,
        uint64 start,
        uint64 cliffDuration,
        uint64 duration
    ) external onlyOwner{
        if(beneficiary == address(0)) revert ZeroAddress();
        if (totalAmount == 0) revert InvalidAmount();
        if (duration == 0 || cliffDuration > duration) revert InvalidDuration();
        if (vestings[beneficiary].initialized) revert VestingAlreadyExists();

        if (token.balanceOf(address(this)) < totalAllocated + totalAmount) revert InsufficientFunding();
        vestings[beneficiary] = VestingSchedule({
            totalAmount : totalAmount,
            released : 0,
            start : start,
            cliffDuration : cliffDuration,
            duration : duration,
            initialized : true

        });
        totalAllocated += totalAmount;
        
        emit VestingCreated(beneficiary, totalAmount, start, cliffDuration, duration);
    }

    function vestedAmount(address beneficiary, uint256 timestamp) public view returns(uint256){
        VestingSchedule memory schedule = vestings[beneficiary];
        if(!schedule.initialized) return 0;

        uint256 cliffEnd = uint256(schedule.start) + uint256(schedule.cliffDuration);
        uint256 vestingEnd = uint256(schedule.start) + uint256(schedule.duration);
    
        if(timestamp < cliffEnd) return 0;

        if(timestamp > vestingEnd) return schedule.totalAmount;

        return (schedule.totalAmount * (timestamp - uint256(schedule.start))) / uint256(schedule.duration);
    }

    function releasableAmount(address beneficiary) public view returns(uint256){
        VestingSchedule memory schedule = vestings[beneficiary];
        if(!schedule.initialized) return 0;

        uint256 vested = vestedAmount(beneficiary, block.timestamp);
        if(vested <= schedule.released) return 0;

        return vested - schedule.released;
    }

    function release() external {
        VestingSchedule storage schedule = vestings[msg.sender];
        if(!schedule.initialized) revert VestingNotFound();

        uint256 amount = releasableAmount(msg.sender);
        if(amount == 0) revert NoTokensToRelease();

        // CEI
        schedule.released += amount;
        totalAllocated -= amount;
        bool ok = token.transfer(msg.sender, amount);
        if(!ok) revert TransferFailed();

        emit TokensReleased(msg.sender, amount);
    }

    function getSchedule(address beneficiary) external view returns(VestingSchedule memory){
        return vestings[beneficiary];
    }

    

}
