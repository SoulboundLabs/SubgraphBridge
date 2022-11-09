// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SubgraphBridge.sol";

contract SubgraphBridgeTest is Test {
    // @notice Contracts
    SubgraphBridgeManager public bridge;
    SubgraphBridgeManager.SubgraphBridge public sampleBridge;
    // @notice SubgraphBridge Config
    bytes32 public queryHash;
    string public queryTemplate = "{testQuery(blockhash:){id}}";
    uint16 public responseDataOffset = 69; // TODO UPDATE THIS
    uint16 public blockHashOffset = 21;
    bytes32 public subgraphDeploymentId =
        keccak256(abi.encodePacked("subgraph"));
    SubgraphBridgeManagerHelpers.BridgeDataType public bridgeDataType =
        SubgraphBridgeManagerHelpers.BridgeDataType.UINT;

    uint8 proposalFreezePeriod = 69;
    uint8 minimumSlashableGRT = 100;
    uint8 minimumExternalStake = 0;
    uint8 disputeResolutionWindow = 0;
    uint8 resolutionThresholdSlashableGRT = 50;
    uint8 resolutionThresholdExternalStake = 0;
    address stakingToken = address(0);

    uint256 public defaultBlockNumber;
    bytes32 public bridgeId;

    function setUp() public {
        address staking = 0xF55041E37E12cD407ad00CE2910B8269B01263b9;
        address dispute = 0x97307b963662cCA2f7eD50e38dCC555dfFc4FB0b;
        bridge = new SubgraphBridgeManager(staking, dispute);
        queryHash = bridge.hashQueryTemplate(queryTemplate);
        sampleBridge = SubgraphBridgeManagerHelpers.SubgraphBridge(
            queryTemplate,
            responseDataOffset,
            blockHashOffset,
            bridgeDataType,
            subgraphDeploymentId,
            proposalFreezePeriod,
            minimumSlashableGRT,
            minimumExternalStake,
            disputeResolutionWindow,
            resolutionThresholdSlashableGRT,
            resolutionThresholdExternalStake,
            stakingToken
        );
        bridge.createSubgraphBridge(sampleBridge);
        emit log_bytes32(bridgeId = bridge._subgraphBridgeID(sampleBridge));
        defaultBlockNumber = block.number;
    }

    function testIfDeployed() public {
        assert(
            0xF55041E37E12cD407ad00CE2910B8269B01263b9 ==
                bridge.theGraphStaking()
        );
    }

    function testPinBlockHash() public {
        bridge.pinBlockHash(defaultBlockNumber);
        vm.expectRevert(bytes("pinBlockHash: already pinned!"));
        bridge.pinBlockHash(defaultBlockNumber);
        bytes32 blockHash = blockhash(defaultBlockNumber);
        emit log_uint(bridge.pinnedBlocks(blockHash));
    }

    function testGenerateQueryRequestCID() public {
        bridge.pinBlockHash(defaultBlockNumber);
        // grabbing param 1
        bytes32 blockhash = blockhash(defaultBlockNumber);
    }
}
