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
        bytes queryFirstChunk; // the first bit of the query up to where the blockhash starts
        bytes queryLastChunk; // the last bit of the query from where the blockhash ends to the end of query
        uint16 responseDataOffset; // index where the data starts in the response string
        BridgeDataType responseDataType; // data type to be extracted from graphQL response string
        bytes32 subgraphDeploymentID; // subgraph being queried
        // dispute handling config
        uint8 proposalFreezePeriod; // undisputed queries can only be executed after this many blocks
        uint8 minimumSlashableGRT; // minimum slashable GRT staked by indexers in order for undisputed proposal to pass
        uint8 disputeResolutionWindow; // how many blocks it takes for disputes to be settled (0 indicates no dispute resolution)
        uint8 resolutionThresholdSlashableGRT; // (30-99) percent of slashable GRT required for dispute resolution
        uint8 resolutionThresholdExternalStake; // (30-99) percentage of external stake required for dispute resolution
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
