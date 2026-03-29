// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Script.sol";
import "../../src/day6/MockERC20.sol";
import "../../src/day6/MiniTokenVesting.sol";

contract DeployMiniTokenVesting is Script {
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 token = new MockERC20("Vesting Token", "VEST");
        MiniTokenVesting vesting = new MiniTokenVesting(address(token));

        token.mint(deployer, 1_000_000e18);
        token.transfer(address(vesting), 100_000e18);

        vm.stopBroadcast();

        console2.log("MockERC20 deployed at:", address(token));
        console2.log("MiniTokenVesting deployed at:", address(vesting));
    }
}
