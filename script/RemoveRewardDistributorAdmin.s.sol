// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Usage:
//   source .env
//   forge script script/RemoveRewardDistributorAdmin.s.sol:RemoveRewardDistributorAdminScript --rpc-url glue --broadcast
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
    function owner() external view returns (address);
}

contract RemoveRewardDistributorAdminScript is Script {
    function run() external {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);
        address rewardDistributor = vm.envAddress("REWARD_DISTRIBUTOR_ADDRESS");
        address adminToRemove = vm.envAddress("ADMIN_ADDRESS");

        console2.log("Removing RewardDistributor admin");
        console2.log("Chain ID:", block.chainid);
        console2.log("Signer:", signer);
        console2.log("RewardDistributor:", rewardDistributor);
        console2.log("Admin to remove:", adminToRemove);

        require(IRewardDistributorAdmin(rewardDistributor).owner() == signer, "Signer is not owner");

        vm.startBroadcast(signerPrivateKey);
        IRewardDistributorAdmin(rewardDistributor).setAdmin(adminToRemove, false);
        vm.stopBroadcast();

        bool enabled = IRewardDistributorAdmin(rewardDistributor).isAdmin(adminToRemove);
        console2.log("Admin enabled:", enabled);
    }
}
