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
    // string public oldQuery = "{tokens(first:1,block:{hash:\"0xc63eaefe604acb284fc4eee85e6dca8676f8c2c354503965c55b2b394713a594\"}){decimals}}";
    string public query = '{"query":"{\n  blocks(first: 10, block: {hash: \"0x0x39b93cc969f3ac620b896a128ee322dbba2e745fb2d6b8ba7218a275b9296648\"}) {\n    id\n    number\n  }\n}","variables":{}}';
    // actual query
    //{\n  blocks(first: 10, block: {hash: \"0xe935226d85b26ee3891c86011216d1f14baef16e40e864b5cb4588ba67259e35\"}) {\n    id\n    number\n  }\n}\n

    // string public queryTemplate = '{"query":"{\n unstakes(first: 10, block: {hash: \"\"}) {\n id\n }\n}\n","variables":{}}';
    string public queryTemplate = '{"query":"{\n  blocks(first: 10, block: {hash: \"\"}) {\n    id\n    number\n  }\n}","variables":{}}';
    uint16 public responseDataOffset = 69; // TODO UPDATE THIS
    uint16 public blockHashOffset = 47; // used to be 30
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

    bytes32 public defaultBlockHash = 0x39b93cc969f3ac620b896a128ee322dbba2e745fb2d6b8ba7218a275b9296648;
    bytes32 public defaultRequestCID = 0x088e483c247ca4554b207bffe11fa57082e1d4ace993301ecfafe7b269114e28;
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

    function testCreateRequestCID() public {
        bytes32 requestCID = 0x088e483c247ca4554b207bffe11fa57082e1d4ace993301ecfafe7b269114e28;
        bytes32 generatedRequestCID = bridge._generateQueryRequestCID(defaultBlockHash, bridgeId);
        assertEq(requestCID, generatedRequestCID);
    }

    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }

    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) public pure returns (string memory res) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        res = string(result);
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }


    function createQuery(string memory _queryTemplate, bytes32 _bridgeId) public returns(string memory) {
        // (,,uint firstLen,,,,,,,,,) = bridge.subgraphBridges(_bridgeId);
        // string memory firstChunk = substring(_queryTemplate, 0, firstLen);
        // emit log_string(firstChunk);
        // uint256 queryTemplateLen = strlen(_queryTemplate);
        //
        // // string memory blockHashString = bytes32ToString(defaultBlockHash);
        // bytes memory blockHashString = hex"39b93cc969f3ac620b896a128ee322dbba2e745fb2d6b8ba7218a275b9296648";
        // // emit log_string(blockHashString);
        //
        // string memory secondChunk = substring(
        //     queryTemplate,
        //     blockHashOffset,
        //     queryTemplateLen
        // );
        // emit log_string(secondChunk);
        //
        // return string.concat(
        //     firstChunk,
        //     blockHashString,
        //     secondChunk
        // );
    }

    function createCID(string memory _queryTemplate, bytes32 _bridgeId) public view returns(bytes32) {
        (,,uint firstLen,,,,,,,,,) = bridge.subgraphBridges(_bridgeId);
        bytes memory firstChunk = bytes(substring(_queryTemplate, 0, firstLen));
        // emit log_string(firstChunk);
        uint256 queryTemplateLen = strlen(_queryTemplate);

        bytes memory blockHashString = bytes(bytes32ToString(defaultBlockHash));
        // emit log_string(blockHashString);

        bytes memory secondChunk = bytes(substring(
            queryTemplate,
            blockHashOffset,
            queryTemplateLen
        ));
        // emit log_string(secondChunk);
        bytes memory joined = bytes.concat(firstChunk, blockHashString, secondChunk);
        return keccak256(joined);
    }

    function testCreateQuery() public {
      emit log_string(createQuery(queryTemplate, bridgeId));
    }

    function testCreateCID() public {
        emit log_bytes32(createCID(queryTemplate, bridgeId));
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
