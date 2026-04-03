// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Script.sol";
import "../../lib/forge-std/src/console2.sol";
import "../../src/day7/MiniMultiSigWallet.sol";

contract DeployDay7 is Script {
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address deployer = vm.addr(deployerPrivateKey);
        address alice = vm.envOr("ALICE", address(0x1111111111111111111111111111111111111111));
        address bob = vm.envOr("BOB", address(0x2222222222222222222222222222222222222222));

        address[] memory _owners = new address[](3);

        _owners[0] = deployer;
        _owners[1] = alice;
        _owners[2] = bob;

        vm.startBroadcast(deployerPrivateKey);

        MiniMultiSigWallet wallet = new MiniMultiSigWallet(_owners, 2);

        vm.stopBroadcast();

        console2.log("MiniMultiSigWallet deployed at:", address(wallet));
        console2.log("Owner 1 (deployer):", deployer);
        console2.log("Owner 2 (alice):", alice);
        console2.log("Owner 3 (bob):", bob);

    }

}
