// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Usage:
// 1) Dry run (no broadcast):
//    source .env
//    forge script script/DeployRewardDistributor.s.sol:DeployRewardDistributorScript --rpc-url glue
//
// 2) Broadcast + verify on Blockscout:
//    source .env
//    forge script script/DeployRewardDistributor.s.sol:DeployRewardDistributorScript --rpc-url glue --broadcast --verify --verifier blockscout --verifier-url https://explorer.glue.net/api
//
// Notes:
// - PRIVATE_KEY must be set in the environment (read via vm.envUint("PRIVATE_KEY")).
// - Explorer config also exists in foundry.toml [etherscan]. The explicit verifier flags above keep the command unambiguous.

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {RewardDistributor} from "../src/RewardDistributor.sol";

contract DeployRewardDistributorScript is Script {
    function run() external returns (RewardDistributor deployed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying RewardDistributor");
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);
        deployed = new RewardDistributor(deployer);
        vm.stopBroadcast();

        require(deployed.owner() == deployer, "Owner mismatch");

        console2.log("RewardDistributor deployed at:", address(deployed));
        console2.log("Owner set to:", deployed.owner());
    }
}
