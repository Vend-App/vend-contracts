// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Usage:
//   source .env
//   forge script script/AddRewardDistributorAdmin.s.sol:AddRewardDistributorAdminScript --rpc-url glue --broadcast
//
// Required env vars:
// - PRIVATE_KEY
// - REWARD_DISTRIBUTOR_ADDRESS
// - ADMIN_ADDRESS

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IRewardDistributorAdmin {
    function setAdmin(address admin, bool enabled) external;
    function isAdmin(address admin) external view returns (bool);
}

contract AddRewardDistributorAdminScript is Script {
    function run() external {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);
        address rewardDistributor = vm.envAddress("REWARD_DISTRIBUTOR_ADDRESS");
        address adminToAdd = vm.envAddress("ADMIN_ADDRESS");

        console2.log("Adding RewardDistributor admin");
        console2.log("Chain ID:", block.chainid);
        console2.log("Signer:", signer);
        console2.log("RewardDistributor:", rewardDistributor);
        console2.log("Admin to add:", adminToAdd);

        vm.startBroadcast(signerPrivateKey);
        IRewardDistributorAdmin(rewardDistributor).setAdmin(adminToAdd, true);
        vm.stopBroadcast();

        bool enabled = IRewardDistributorAdmin(rewardDistributor).isAdmin(adminToAdd);
        console2.log("Admin enabled:", enabled);
    }
}
