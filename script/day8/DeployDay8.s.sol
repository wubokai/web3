// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Script.sol";
import "../../src/day8/MiniTimelockController.sol";

contract DeployDay8 is Script {
    function run() external returns (MiniTimelockController timelock){
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 minDelay = 1 days;

        vm.startBroadcast(deployerPrivateKey);

        timelock = new MiniTimelockController(deployer, minDelay);

        vm.stopBroadcast();
    }
}