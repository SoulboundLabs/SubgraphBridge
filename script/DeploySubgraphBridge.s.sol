// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/SubgraphBridge.sol";

contract DeploySubgraphBridge is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // goerli address
        address staking = 0x35e3Cb6B317690d662160d5d02A5b364578F62c9;
        // goerli address
        address dispute = 0x8c344366D9269174F10bB588F16945eb47f78dc9;

        new SubgraphBridgeManager(staking, dispute);

        vm.stopBroadcast();
    }
}
