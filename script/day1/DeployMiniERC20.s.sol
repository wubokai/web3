// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../lib/forge-std/src/Script.sol";
import "../../src/day1/MiniERC20.sol";

contract DeployMiniERC20 is Script {
    function run() external returns (MiniERC20 token) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        token = new MiniERC20("Mini Token", "MTK", 18);

        // 可选：部署后给部署者 mint 一部分
        token.mint(vm.addr(deployerPrivateKey), 1_000_000 ether);

        vm.stopBroadcast();

        console2.log("MiniERC20 deployed at:", address(token));
        console2.log("Owner:", token.owner());
        console2.log("Deployer balance:", token.balanceOf(vm.addr(deployerPrivateKey)));
    }
}