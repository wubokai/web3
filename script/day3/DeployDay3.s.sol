// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Script.sol";
import {MiniERC1155} from "../../src/day3/MiniERC1155.sol";
import {MultiTokenSale} from "../../src/day3/MultiTokenSale.sol";

contract DeployDay3 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MiniERC1155 token = new MiniERC1155("ipfs://my-game-items/{id}.json");
        MultiTokenSale sale = new MultiTokenSale(address(token));

        token.mint(address(sale), 1, 100);
        token.mint(address(sale), 2, 50);
        token.mint(address(sale), 3, 10);

        sale.setPrice(1, 0.01 ether);
        sale.setPrice(2, 0.02 ether);
        sale.setPrice(3, 0.05 ether);

        vm.stopBroadcast();

        console2.log("MiniERC1155 deployed at:", address(token));
        console2.log("MultiTokenSale deployed at:", address(sale));
    }
}