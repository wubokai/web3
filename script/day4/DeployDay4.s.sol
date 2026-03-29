// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Script.sol";
import "../../lib/forge-std/src/console2.sol";
import "../../src/day4/MockERC20.sol";
import "../../src/day4/MiniStakingRewards.sol";

contract DeployDay4 is Script {
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 stakingToken = new MockERC20("Stake Token", "STK");
        MockERC20 rewardToken = new MockERC20("Reward Token", "RWD");

        MiniStakingRewards staking = new MiniStakingRewards(
            address(stakingToken),
            address(rewardToken),
            1e18 // 1 reward token per second
        );

        stakingToken.mint(deployer, 1_000_000e18);
        rewardToken.mint(deployer, 1_000_000e18);

        rewardToken.transfer(address(staking), 500_000e18);

        vm.stopBroadcast();

        console2.log("stakingToken:", address(stakingToken));
        console2.log("rewardToken :", address(rewardToken));
        console2.log("staking     :", address(staking));

    }
}
