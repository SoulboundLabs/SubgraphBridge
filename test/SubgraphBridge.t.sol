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
    string public query = "{tokens(first:1,block:{hash:\"0xc63eaefe604acb284fc4eee85e6dca8676f8c2c354503965c55b2b394713a594\"}){decimals}}";
    string public queryTemplate = "{tokens(first:1,block:{hash:\\\"\\\"}){decimals}}";
    uint16 public responseDataOffset = 69; // TODO UPDATE THIS
    uint16 public blockHashOffset = 30;
    // uint16 public blockHashOffset = 10;
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

    bytes32 public defaultBlockHash = 0xc63eaefe604acb284fc4eee85e6dca8676f8c2c354503965c55b2b394713a594;
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
        bridgeId = bridge._subgraphBridgeID(sampleBridge);
        emit log_bytes32(bridgeId);
        defaultBlockNumber = block.number;
    }

    function testIfDeployed() public view {
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

    //TODO: Figure out how the query is being generated so we can format query -> whatever needs to be hashed to get the requestCID
    function testCreateRequestCID() public {
        bytes32 requestCID = 0xf61499b5e9584435bda7432da624fc1754823998c1753f1fad9b95ec276ba6a3;
        bytes32 generatedRequestCID = bridge._generateQueryRequestCID(defaultBlockHash, bridgeId);
        assertEq(requestCID, generatedRequestCID);
    }

    function testQueryAndResponseMatchAttestation() public {
      // do something
    }

    function testParseAttestation() public {
        // do something
    }

    function testExtractData() public {
        // do something
    }

    function testCertifySubgraphResponse() public {
        // do something
    }

    function testPostSubgraphResponse() public {
        // do something
    }
}
