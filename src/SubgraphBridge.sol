pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "./dependencies/TheGraph/IController.sol";
import "./dependencies/TheGraph/IStaking.sol";
import "./dependencies/TheGraph/IDisputeManager.sol";
import "./SubgraphBridgeHelpers.sol";

//@title SubgraphBridge
//@notice SubgraphBridge is a contract that allows us to bridge subgraph data from The Graph's Decentralized Network to Ethereum in a cryptoeconomically secure manner.
contract SubgraphBridgeManager is SubgraphBridgeManagerHelpers {
    address public theGraphStaking;
    address public theGraphDisputeManager;

    // {block hash} -> {block number}
    mapping(bytes32 => uint256) public pinnedBlocks;

    // {SubgraphBridgeID} -> {SubgraphBridge}
    mapping(bytes32 => SubgraphBridge) public subgraphBridges;

    // {SubgraphBridgeID} -> {attestation.requestCID} -> {SubgraphBridgeProposals}
    mapping(bytes32 => mapping(bytes32 => SubgraphBridgeProposals))
        public subgraphBridgeProposals;

    // not yet implemented
    // {SubgraphBridgeID} -> {attestation.requestCID} -> {block number}
    mapping(bytes32 => mapping(bytes32 => uint256))
        public bridgeConflictResolutionBlock;

    // {SubgraphBridgeID} -> {requestCID} -> {responseData}
    mapping(bytes32 => mapping(bytes32 => uint256)) public subgraphBridgeData;

    constructor(address staking, address disputeManager) {
        theGraphStaking = staking;
        theGraphDisputeManager = disputeManager;
    }

    // ============================================================
    // PUBLIC FUNCTIONS TO BE USED BY THE MASSES
    // ============================================================

    //@notice creates a query bridge
    //@dummy create a way to get subgraph query results back on chain
    function createSubgraphBridge(SubgraphBridge memory subgraphBridge) public {
        bytes32 subgraphBridgeID = _subgraphBridgeID(subgraphBridge); // set the subgraphId to the hashed SubgraphBridge
        subgraphBridges[subgraphBridgeID] = subgraphBridge;
    }

    // @notice, this function is used to provide an attestation for a query
    // @dummy, whoever calls this is providing the data for ur query
    // @param blockNumber, the block number of the block that the request was made for
    // @param query, the query that was made
    // @param response, the response of the query
    // @param subgraphBridgeID, the ID of the subgraph bridge
    // @param calldata attestation, the attestation of the response
    function postSubgraphResponse(
        uint256 blockNumber,
        string calldata query,
        string calldata response,
        bytes32 subgraphBridgeID,
        bytes calldata attestationData
    ) public {
        bytes32 pinnedBlockHash = blockhash(blockNumber);
        // If the block number -> blockhash isn't pinned, pin it
        if (pinnedBlocks[pinnedBlockHash] == 0) {
            pinnedBlocks[pinnedBlockHash] = blockNumber;
        }
        require(
            subgraphBridges[subgraphBridgeID].blockHashOffset > 0,
            "query bridge doesn't exist"
        );

        IDisputeManager.Attestation memory attestation = _parseAttestation(
            attestationData
        );
        require(
            _queryAndResponseMatchAttestation(
                blockhash(blockNumber),
                subgraphBridgeID,
                response,
                attestation
            ),
            "query/response != attestation"
        );

        // get indexer's slashable stake from staking contract
        address attestationIndexer = IDisputeManager(theGraphDisputeManager)
            .getAttestationIndexer(attestation);
        uint256 indexerStake = IStaking(theGraphStaking).getIndexerStakedTokens(
            attestationIndexer
        );
        require(indexerStake > 0, "indexer doesn't have slashable stake");

        SubgraphBridgeProposals storage proposals = subgraphBridgeProposals[
            subgraphBridgeID
        ][attestation.requestCID];

        if (
            proposals
                .stake[attestation.responseCID]
                .totalStake
                .attestationStake == 0
        ) {
            proposals.proposalCount = proposals.proposalCount + 1;

            uint16 blockHashOffset = subgraphBridges[subgraphBridgeID]
                .blockHashOffset;
            bytes32 queryBlockHash = _bytes32FromStringWithOffset(
                query,
                blockHashOffset + 2
            ); // todo: why +2?
            require(pinnedBlocks[queryBlockHash] > 0, "block hash unpinned");
        }

        // update stake values
        proposals
            .stake[attestation.responseCID]
            .accountStake[attestationIndexer]
            .attestationStake = indexerStake;
        proposals.stake[attestation.responseCID].totalStake.attestationStake =
            proposals
                .stake[attestation.responseCID]
                .totalStake
                .attestationStake +
            indexerStake;
        proposals.totalStake.attestationStake =
            proposals.totalStake.attestationStake +
            indexerStake;
    }

    //@notice, this function allows you to use a non disputed query response after the dispute period has ended
    //@dummy, use this function to slurp up your query data

    //@dev for a subgraphBridge, we are certifying data at a specific block hash
    function certifySubgraphResponse(
        uint256 blockNumber,
        string calldata response,
        bytes32 subgraphBridgeId,
        bytes calldata attestationData // contains cid of response and request
    ) public {
        uint16 blockHashOffset = subgraphBridges[subgraphBridgeId]
            .blockHashOffset + 2;
        bytes32 _blockhash = blockhash(blockNumber);
        IDisputeManager.Attestation memory attestation = _parseAttestation(
            attestationData
        );
        bytes32 requestCID = attestation.requestCID;
        // bytes32 queryBlockHash = _bytes32FromStringWithOffset(blockHashOffset); // todo: why +2?
        // bytes32 queryTemplateHash = subgraphBridges[subgraphBridgeId].queryTemplate;
        // bytes32 subgraphDeploymentID = subgraphBridges[subgraphBridgeId].subgraphDeploymentID;
        // uint16 responseDataOffset = subgraphBridges[subgraphBridgeId].responseDataOffset;
        uint8 proposalFreezePeriod = subgraphBridges[subgraphBridgeId]
            .proposalFreezePeriod;
        uint8 minimumSlashableGRT = subgraphBridges[subgraphBridgeId]
            .minimumSlashableGRT;

        require(
            pinnedBlocks[_blockhash] + proposalFreezePeriod <= block.number,
            "proposal still frozen"
        );

        SubgraphBridgeProposals storage proposals = subgraphBridgeProposals[
            subgraphBridgeId
        ][requestCID];
        require(proposals.proposalCount == 1, "proposalCount must be 1");

        // TODO: CHECK THIS IS WORKIN RIGHT
        bytes32 responseCID = keccak256(abi.encodePacked(response));

        require(
            proposals.stake[responseCID].totalStake.attestationStake >
                minimumSlashableGRT,
            "not enough stake"
        );

        _extractData(subgraphBridgeId, requestCID, response);
    }

    // ============================================================
    // INTERNAL AND HELPER FUNCTIONS
    // ============================================================
    function pinBlockHash(uint256 blockNumber) public {
        require(
            pinnedBlocks[blockhash(blockNumber)] == 0,
            "pinBlockHash: already pinned!"
        );
        pinnedBlocks[blockhash(blockNumber)] = blockNumber;
    }

    function _extractData(
        bytes32 subgraphBridgeID,
        bytes32 requestCID,
        string calldata response
    ) private {
        uint256 responseT = uint256(
            subgraphBridges[subgraphBridgeID].responseDataType
        );
        if (
            subgraphBridges[subgraphBridgeID].responseDataType ==
            BridgeDataType.UINT
        ) {
            subgraphBridgeData[subgraphBridgeID][requestCID] = _uintFromString(
                response,
                subgraphBridges[subgraphBridgeID].responseDataOffset
            );
            string memory s = response[subgraphBridges[subgraphBridgeID]
                .responseDataOffset:];
        }
    }

    /**
     *@notice this function checks if a query for a subgraphBridgeId matches the attestation
     *@param blockHash, the blockhash we are serving data for
     *@param subgraphBridgeID, the subgraph bridge id
     *@param response, the response from the subgraph query
     *@param attestation, the attestation from the indexer
     *@return bool, returns true if everything matches, fails otherwise
     */
    function _queryAndResponseMatchAttestation(
        bytes32 blockHash,
        bytes32 subgraphBridgeID,
        string calldata response,
        IDisputeManager.Attestation memory attestation
    ) internal view returns (bool) {
        require(
            attestation.requestCID ==
                _generateQueryRequestCID(blockHash, subgraphBridgeID),
            "_queryAndResponseMatchAttestation: RequestCID Doesn't match"
        );
        require(
            attestation.responseCID == keccak256(abi.encodePacked(response)),
            "_queryAndResponseMatchAttestation: ResponseCID Doesn't Match"
        );
        require(
            subgraphBridges[subgraphBridgeID].subgraphDeploymentID ==
                attestation.subgraphDeploymentID,
            "_queryAndResponseMatchAttestation: SubgraphDeploymentID Doesn't Match"
        );
        return true;
    }

    /**
     * @dev Parse the bytes attestation into a struct from `_data`.
     * @return Attestation struct
     */
    function _parseAttestation(bytes memory _data)
        internal
        pure
        returns (IDisputeManager.Attestation memory)
    {
        // Check attestation data length
        require(
            _data.length == ATTESTATION_SIZE_BYTES,
            "Attestation must be 161 bytes long"
        );

        // Decode receipt
        (
            bytes32 requestCID,
            bytes32 responseCID,
            bytes32 subgraphDeploymentID
        ) = abi.decode(_data, (bytes32, bytes32, bytes32));

        // Decode signature
        // Signature is expected to be in the order defined in the Attestation struct
        bytes32 r = _toBytes32(_data, SIG_R_OFFSET);
        bytes32 s = _toBytes32(_data, SIG_S_OFFSET);
        uint8 v = _toUint8(_data, SIG_V_OFFSET);

        return
            IDisputeManager.Attestation(
                requestCID,
                responseCID,
                subgraphDeploymentID,
                r,
                s,
                v
            );
    }

    /**
     *@dev this function generates (WHAT SHOULD BE) the requestCID for the query at a blocknumber
     *@param _blockhash, the blockchash we are querying
     *@param _subgraphBridgeId, the id of the subgraphBridge
     *@return the keccak256 hash of the request
     */
    function _generateQueryRequestCID(
        bytes32 _blockhash,
        bytes32 _subgraphBridgeId
    ) public view returns (bytes32) {
        SubgraphBridge storage bridge = subgraphBridges[_subgraphBridgeId];

        //NOTE: TEST IF THE substring function is inclusive of the stop index
        uint256 firstLen = bridge.blockHashOffset - 1; // length from start-> block
        string memory firstChunk = substring(bridge.queryTemplate, 0, firstLen);
        string memory secondChunk = substring(
            bridge.queryTemplate,
            bridge.blockHashOffset + BLOCKHASH_LENGTH,
            strlen(bridge.queryTemplate)
        );
        return
            keccak256(
                bytes(abi.encodePacked(firstChunk, _blockhash, secondChunk))
            );
    }
}
