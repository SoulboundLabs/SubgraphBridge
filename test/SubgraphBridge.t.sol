// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SubgraphBridge.sol";

contract SubgraphBridgeTest is Test {
    SubgraphBridgeManager public bridge;
    SubgraphBridgeManager.SubgraphBridge public sampleBridge;

    function setUp() public {
        address staking = 0xF55041E37E12cD407ad00CE2910B8269B01263b9;
        address dispute = 0x97307b963662cCA2f7eD50e38dCC555dfFc4FB0b;
        bridge = new SubgraphBridgeManager(staking, dispute);
    }

    function testIfDeployed() public {
        assert(
            0xF55041E37E12cD407ad00CE2910B8269B01263b9 ==
                bridge.theGraphStaking()
        );
    }

    function testPinBlockHash() public {
        uint256 blockNum = block.number;
        bridge.pinBlockHash(blockNum);
        vm.expectRevert(bytes("pinBlockHash: already pinned!"));
        bridge.pinBlockHash(blockNum);
        bytes32 blockHash = blockhash(blockNum);
        emit log_uint(bridge.pinnedBlocks(blockHash));
    }
}
