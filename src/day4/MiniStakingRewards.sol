// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MiniStakingRewards {
    uint256 private constant PRECISION = 1e27;

    IERC20Minimal public immutable stakingToken;
    IERC20Minimal public immutable rewardToken;
    address public owner;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    error NotOwner();
    error ZeroAmount();
    error InsufficientBalance();
    error ZeroAddress();

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRewardRate);
    event OwnerUpdated(address indexed newOwner);


    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate) {
        if (_stakingToken == address(0) || _rewardToken == address(0)) revert ZeroAddress();

        stakingToken = IERC20Minimal(_stakingToken);
        rewardToken = IERC20Minimal(_rewardToken);

        owner = msg.sender;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;

    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if(account != address(0)){
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if(totalSupply == 0) return rewardPerTokenStored; 

        uint256 time = block.timestamp - lastUpdateTime;
        return rewardPerTokenStored + (time * rewardRate * PRECISION) / totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        uint256 paid = userRewardPerTokenPaid[account];
        uint256 current = rewardPerToken();
        uint256 newlyAccrued = (balanceOf[account] * (current - paid)) / PRECISION;

        return rewards[account] + newlyAccrued;
    }

    function stake(uint256 amount) external updateReward(msg.sender){
        if(amount == 0) revert ZeroAmount();

        balanceOf[msg.sender] += amount;
        totalSupply += amount;
        bool ok = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(ok,"failed");

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public updateReward(msg.sender){
        if(amount == 0) revert ZeroAmount();
        if(amount>balanceOf[msg.sender]) revert InsufficientBalance();

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        bool ok = stakingToken.transfer(msg.sender, amount);
        require(ok,"failed");
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public updateReward(msg.sender){
        uint256 reward = rewards[msg.sender];
        if(reward == 0) return;

        rewards[msg.sender] =0;
        bool ok = rewardToken.transfer(msg.sender, reward);
        require(ok,"failed");   
        emit RewardPaid(msg.sender, reward);
    }

    function exit() external{
        uint256 bal = balanceOf[msg.sender];
        if(bal > 0){
            withdraw(bal);
        }
        getReward();
    }

    function setRewardRate(uint256 newRewardRate) external onlyOwner updateReward(address(0)){
        rewardRate = newRewardRate;
        emit RewardRateUpdated(newRewardRate);
    }

    function transferOwnership(address newOwner) external onlyOwner{
        owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

}
