// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import "../../src/day4/MockERC20.sol";
import "../../src/day4/MiniStakingRewards.sol";

contract MiniStakingRewardsTest is Test {
    MockERC20 stakingToken;
    MockERC20 rewardToken;
    MiniStakingRewards staking;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address charlie = address(0xC0FFEE);

    uint256 constant INITIAL_REWARD_RATE = 1e18; // 1 token / second

    function setUp() public{
        stakingToken = new MockERC20("Stake Token", "STK");
        rewardToken = new MockERC20("Reward Token", "RWD");

        staking = new MiniStakingRewards(
            address(stakingToken),
            address(rewardToken),
            INITIAL_REWARD_RATE
        );

        stakingToken.mint(alice, 1_000e18);
        stakingToken.mint(bob, 1_000e18);
        stakingToken.mint(charlie, 1_000e18);

        rewardToken.mint(address(this), 1_000_000e18);
        rewardToken.transfer(address(staking), 500_000e18);

        vm.prank(alice);
        stakingToken.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        stakingToken.approve(address(staking), type(uint256).max);

        vm.prank(charlie);
        stakingToken.approve(address(staking), type(uint256).max);

    }

    function test_Stake() public {
        vm.prank(alice);
        staking.stake(100e18);

        assertEq(staking.balanceOf(alice), 100e18);
        assertEq(staking.totalSupply(), 100e18);
        assertEq(stakingToken.balanceOf(alice), 900e18);
        assertEq(stakingToken.balanceOf(address(staking)), 100e18);
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        staking.stake(100e18);
        staking.withdraw(40e18);
        vm.stopPrank();

        assertEq(staking.balanceOf(alice), 60e18);
        assertEq(staking.totalSupply(), 60e18);
        assertEq(stakingToken.balanceOf(alice), 940e18);
        assertEq(stakingToken.balanceOf(address(staking)), 60e18);
    }

    function test_GetReward() public {
        vm.startPrank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 100);

        staking.getReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(alice), 100e18);
        assertEq(staking.rewards(alice), 0);
    }

    function test_EarnedAccruesOverTime() public {
        vm.prank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 100);

        uint256 reward = staking.earned(alice);
        assertEq(reward, 100e18);
    }

    function test_TwoUsersShareRewardsProportionally() public {
        vm.prank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 100);

        vm.prank(bob);
        staking.stake(100e18);

        vm.warp(block.timestamp + 100);

        uint256 aliceEarned = staking.earned(alice);
        uint256 bobEarned = staking.earned(bob);

        // 前100秒 Alice独享 = 100
        // 后100秒 两人平分，各50
        // Alice总共150, Bob总共50
        assertEq(aliceEarned, 150e18);
        assertEq(bobEarned, 50e18);
    }

    function test_RevertWhen_StakeZero() public {
        vm.prank(alice);
        vm.expectRevert(MiniStakingRewards.ZeroAmount.selector);
        staking.stake(0);
    }

    function test_RevertWhen_WithdrawZero() public {
        vm.prank(alice);
        vm.expectRevert(MiniStakingRewards.ZeroAmount.selector);
        staking.withdraw(0);
    }

    function test_RevertWhen_WithdrawMoreThanBalance() public {
        vm.prank(alice);
        staking.stake(100e18);

        vm.prank(alice);
        vm.expectRevert(MiniStakingRewards.InsufficientBalance.selector);
        staking.withdraw(101e18);
    }

    function test_GetRewardClearsPendingReward() public {
        vm.startPrank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 50);
        assertEq(staking.earned(alice), 50e18);

        staking.getReward();
        assertEq(staking.earned(alice), 0);

        vm.warp(block.timestamp + 20);
        assertEq(staking.earned(alice), 20e18);
        vm.stopPrank();
    }

    function test_RewardPerTokenDoesNotChangeWhenNoSupply() public {
        uint256 beforeValue = staking.rewardPerToken();

        vm.warp(block.timestamp + 1000);

        uint256 afterValue = staking.rewardPerToken();
        assertEq(beforeValue, afterValue);
    }

    function test_SetRewardRate() public {
        staking.setRewardRate(2e18);
        assertEq(staking.rewardRate(), 2e18);
    }

    function test_RevertWhen_NonOwnerSetRewardRate() public {
        vm.prank(alice);
        vm.expectRevert(MiniStakingRewards.NotOwner.selector);
        staking.setRewardRate(2e18);
    }

    function test_Exit() public {
        vm.startPrank(alice);
        staking.stake(200e18);

        vm.warp(block.timestamp + 10);

        staking.exit();
        vm.stopPrank();

        assertEq(staking.balanceOf(alice), 0);
        assertEq(staking.totalSupply(), 0);
        assertEq(stakingToken.balanceOf(alice), 1_000e18);
        assertEq(rewardToken.balanceOf(alice), 10e18);
    }

    function test_MultipleClaimsAccumulateCorrectly() public {
        vm.startPrank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 30);
        staking.getReward();
        assertEq(rewardToken.balanceOf(alice), 30e18);

        vm.warp(block.timestamp + 20);
        staking.getReward();
        assertEq(rewardToken.balanceOf(alice), 50e18);
        vm.stopPrank();
    }

    function test_WithdrawDoesNotLoseAccruedReward() public {
        vm.startPrank(alice);
        staking.stake(100e18);

        vm.warp(block.timestamp + 50);
        staking.withdraw(40e18);

        // 前50秒全部按100 stake算，所以先累计50 reward
        assertEq(staking.earned(alice), 50e18);

        vm.warp(block.timestamp + 10);
        // 剩余60 stake，再过10秒，新增10 reward
        assertApproxEqAbs(staking.earned(alice), 60e18, 1);
        vm.stopPrank();
    }

}
