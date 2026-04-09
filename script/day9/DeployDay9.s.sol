// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../lib/forge-std/src/Script.sol";
import "../../src/day9/GovernanceToken.sol";
import "../../src/day9/MiniTimelockController.sol";
import "../../src/day9/MiniGovernor.sol";
import "../../src/day9/Box.sol";

contract DeployDay9 is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);

        uint256 votingDelay = 1 days;
        uint256 votingPeriod = 3 days;
        uint256 proposalThreshold = 100 ether;
        uint256 quorum = 300 ether;
        uint256 timelockDelay = 2 days;

        vm.startBroadcast(deployerPk);

        GovernanceToken token = new GovernanceToken();

        MiniTimelockController timelock = new MiniTimelockController(
            timelockDelay,
            deployer
        );

        MiniGovernor governor = new MiniGovernor(
            address(token),
            address(timelock),
            votingDelay,
            votingPeriod,
            proposalThreshold,
            quorum
        );

        Box box = new Box(address(timelock));

        timelock.setProposer(address(governor), true);
        timelock.setExecutor(address(governor), true);

        token.mint(deployer, 1_000_000 ether);

        vm.stopBroadcast();

        console.log("GovernanceToken:", address(token));
        console.log("MiniTimelockController:", address(timelock));
        console.log("MiniGovernor:", address(governor));
        console.log("Box:", address(box));
    }
}