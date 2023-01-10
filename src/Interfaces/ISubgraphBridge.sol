pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

interface ISubgraphBridge {
    enum BridgeDataType {
        ADDRESS,
        BYTES32,
        UINT
        // TODO: STRING
    }

    struct SubgraphBridge {
        // ---QUERY AND RESPONSE CONFIG---
        bytes queryFirstChunk; // the first bit of the query up to where the blockhash starts
        bytes queryLastChunk; // the last bit of the query from where the blockhash ends to the end of query
        BridgeDataType responseDataType; // data type to be extracted from graphQL response string
        bytes32 subgraphDeploymentID; // subgraph being queried
        // ---DISPUTE HANLDING CONFIG---
        uint208 proposalFreezePeriod; // undisputed queries can only be executed after this many blocks
        uint16 responseDataOffset; // index where the data starts in the response string
        uint256 minimumSlashableGRT; // minimum slashable GRT staked by indexers in order for undisputed proposal to pass
    }

    function createSubgraphBridge(SubgraphBridge memory subgraphBridge)
        external;

    function postSubgraphResponse(
        bytes32 blockHash,
        bytes32 subgraphBridgeID,
        string calldata response,
        bytes calldata attestationData
    ) external;

    function certifySubgraphResponse(
        bytes32 _blockhash,
        string calldata response,
        bytes32 subgraphBridgeID,
        bytes calldata attestationData
    ) external;

    function subgraphBridgeData(bytes32 bridgeID, bytes32 requestCID)
        external
        view
        returns (BridgeDataType);
}
