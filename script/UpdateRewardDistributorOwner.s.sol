// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Usage:
//   source .env
//   forge script script/UpdateRewardDistributorOwner.s.sol:UpdateRewardDistributorOwnerScript --rpc-url glue --broadcast
//
// Required env vars:
// - PRIVATE_KEY
// - REWARD_DISTRIBUTOR_ADDRESS
// - OWNER_ADDRESS

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IRewardDistributorOwner {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

contract UpdateRewardDistributorOwnerScript is Script {
    function run() external {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        address signer = vm.addr(signerPrivateKey);
        address rewardDistributor = vm.envAddress("REWARD_DISTRIBUTOR_ADDRESS");
        address newOwner = vm.envAddress("OWNER_ADDRESS");

        console2.log("Updating RewardDistributor owner");
        console2.log("Chain ID:", block.chainid);
        console2.log("Signer:", signer);
        console2.log("RewardDistributor:", rewardDistributor);
        console2.log("New owner:", newOwner);

        require(IRewardDistributorOwner(rewardDistributor).owner() == signer, "Signer is not owner");

        vm.startBroadcast(signerPrivateKey);
        IRewardDistributorOwner(rewardDistributor).transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
