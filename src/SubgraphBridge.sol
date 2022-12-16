pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "./dependencies/TheGraph/IController.sol";
import "./dependencies/TheGraph/IStaking.sol";
import "./dependencies/TheGraph/IDisputeManager.sol";
import "./SubgraphBridgeHelpers.sol";

/**
 * @title SubgraphBridge
 * @dev SubgraphBridge is a contract that allows us to bridge subgraph data from The Graph's Decentralized Network to Ethereum in a cryptoeconomically secure manner.
 * @author Soulbound Labs (Connor Dunham, Alexander Gusev, and Jordan Rein)
 */
contract SubgraphBridgeManager is SubgraphBridgeManagerHelpers {
    address public theGraphStaking;
    address public theGraphDisputeManager;

    /**
    @notice A mapping storing blockhashes -> blocknumber
    */
    // mapping(bytes32 => uint256) public pinnedBlocks;

    mapping(uint256 => bytes32) public pinnedBlocks;

    /**
    @notice A mapping storing subgraphBridgID -> SubgraphBridge
     */
    mapping(bytes32 => SubgraphBridge) public subgraphBridges;

    /**
     *@notice A mapping storing subgraphBridgeID -> RequestCID -> SubgraphBridgeProposals
     */
    mapping(bytes32 => mapping(bytes32 => SubgraphBridgeProposals))
        public subgraphBridgeProposals;

    /**
     *@notice A mapping storing subgraphBridgeID -> RequestCID -> ResponseDataBytes
     */
    mapping(bytes32 => mapping(bytes32 => bytes)) public subgraphBridgeData;

    /**
     *@notice A mapping storing requestCID -> DisputeID Array
     */
    mapping(bytes32 => bytes32[]) public queryDisputes;

    /**
     *@notice The latest subgraph bridge data for a subgraphBridgeID
     */
    mapping(bytes32 => bytes) public latestSubgraphBridgeData;

    event SubgraphQueryDisputeCreated(
        bytes32 indexed subgraphBridgeID,
        bytes32 indexed requestCID,
        bytes32 disputeID
    );

    event SubgraphBridgeCreation(
        address bridgeCreator,
        bytes32 subgraphBridgeId,
        bytes32 subgraphDeploymentID,
        bytes queryFirstChunk,
        bytes queryLastChunk,
        uint256 responseDataType,
        uint208 proposalFreezePeriod,
        uint16 responseDataOffset,
        uint256 minimumSlashableGRT
    );

    event SubgraphResponseAdded(
        address queryBridger,
        bytes32 subgraphBridgeID,
        bytes32 subgraphDeploymentID,
        string response,
        bytes attestationData,
        uint256 unlocksAt,
        bytes32 requestCID
    );

    event QueryResultFinalized(
        bytes32 subgraphBridgeID,
        bytes32 requestCID,
        string response
    );

    constructor(address staking, address disputeManager) {
        theGraphStaking = staking;
        theGraphDisputeManager = disputeManager;
    }

    // ============================================================
    // PUBLIC FUNCTIONS TO BE USED BY THE MASSES
    // ============================================================

    /**
     *@notice creates a query bridge
     *@param subgraphBridge the subgraph bridge to be created
     */
    function createSubgraphBridge(SubgraphBridge memory subgraphBridge) public {
        bytes32 subgraphBridgeID = _subgraphBridgeID(subgraphBridge); // set the subgraphId to the hashed SubgraphBridge
        subgraphBridges[subgraphBridgeID] = subgraphBridge;
        emit SubgraphBridgeCreation(
            msg.sender,
            subgraphBridgeID,
            subgraphBridge.subgraphDeploymentID,
            subgraphBridge.queryFirstChunk,
            subgraphBridge.queryLastChunk,
            uint256(subgraphBridge.responseDataType),
            subgraphBridge.proposalFreezePeriod,
            subgraphBridge.responseDataOffset,
            subgraphBridge.minimumSlashableGRT
        );
    }

    /**
     *@notice this function is used to provide an attestation for a query
     *@param blockNumber, the block number of the block that the request was made for
     *@param subgraphBridgeID, the ID of the subgraph bridge
     *@param response, the response of the query
     *@param attestationData the attestation of the response
     */

    function postSubgraphResponse(
        uint256 blockNumber,
        bytes32 subgraphBridgeID,
        string calldata response,
        bytes calldata attestationData
    ) public {
        if (pinnedBlocks[blockNumber] == 0) {
            pinBlockHash(blockNumber);
        }

        bytes32 blockHash = pinnedBlocks[blockNumber];

        require(pinnedBlocks[blockNumber] != 0, "Block not pinned");

        require(
            subgraphBridges[subgraphBridgeID].responseDataOffset != 0,
            "query bridge doesn't exist"
        );

        IDisputeManager.Attestation memory attestation = parseAttestation(
            attestationData
        );
        require(
            queryAndResponseMatchAttestation(
                blockHash,
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
        }
        // if this is the first proposal, use this block number to start the dispute window
        uint256 firstBlockNumber = proposals.responseProposals.length > 0
            ? proposals.responseProposals[0].proposalBlockNumber
            : block.number;

        proposals.responseProposals.push(
            ResponseProposal(
                attestation.responseCID,
                attestationData,
                firstBlockNumber
            )
        );

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

        // loop over all of the responseProposals and check if the responseCID is equal for all of them, if not open a new conflict
        for (uint256 i; i < proposals.responseProposals.length; i++) {
            bytes32 _responseCID = proposals.responseProposals[i].responseCID;
            if (attestation.responseCID != _responseCID) {
                // create a query dispute
                createQueryDispute(
                    subgraphBridgeID,
                    attestation.requestCID,
                    attestation.responseCID, //responseCID of this proposal
                    _responseCID, //responseCID of the conflicting proposal
                    i, // index of the conflicting proposal
                    proposals.responseProposals.length - 1 // index of the submitted proposal
                );
            }
        }

        uint256 unlocksAt = firstBlockNumber +
            subgraphBridges[subgraphBridgeID].proposalFreezePeriod;

        emit SubgraphResponseAdded(
            msg.sender,
            subgraphBridgeID,
            attestation.subgraphDeploymentID,
            response,
            attestationData,
            unlocksAt,
            attestation.requestCID
        );
    }

    /**
     *@notice this function allows you to use a non disputed query response after the dispute period has ended
     *@param subgraphBridgeID, the ID of the subgraph bridge
     *@param response, the response of the query
     *@param attestationData, the attestation of the response
     */

    function certifySubgraphResponse(
        bytes32 subgraphBridgeID,
        string calldata response,
        bytes calldata attestationData // contains cid of response and request
    ) public {
        IDisputeManager.Attestation memory attestation = parseAttestation(
            attestationData
        );
        bytes32 requestCID = attestation.requestCID;
        require(
            !isQueryDisputed(attestation.requestCID),
            "certifySubgraphResponse: There is a query dispute for this request"
        );

        uint208 proposalFreezePeriod = subgraphBridges[subgraphBridgeID]
            .proposalFreezePeriod;

        uint256 minimumSlashableGRT = subgraphBridges[subgraphBridgeID]
            .minimumSlashableGRT;

        SubgraphBridgeProposals storage proposals = subgraphBridgeProposals[
            subgraphBridgeID
        ][requestCID];

        require(
            proposals.proposalCount >= 1,
            "proposalCount must be at least 1"
        );

        uint256 proposalFirstBlock = proposals
            .responseProposals[0]
            .proposalBlockNumber;

        require(
            proposalFirstBlock + proposalFreezePeriod <= block.number,
            "proposal still frozen"
        );

        bytes32 responseCID = keccak256(abi.encodePacked(response));

        require(
            proposals.stake[responseCID].totalStake.attestationStake >
                minimumSlashableGRT,
            "not enough stake"
        );

        _extractData(subgraphBridgeID, requestCID, response);

        // update the latestSubgraphBridgeData
        latestSubgraphBridgeData[subgraphBridgeID] = subgraphBridgeData[
            subgraphBridgeID
        ][requestCID];
        emit QueryResultFinalized(subgraphBridgeID, requestCID, response);
    }

    // ============================================================
    // INTERNAL AND HELPER FUNCTIONS
    // ============================================================

    /**
     *@notice this function is used to open a dispute for two conflicting proposals
     *@param subgraphBridgeID, the ID of the subgraph bridge
     *@param requestCID, the CID of the request
     *@param responseCID1, the CID of the first response
     *@param responseCID2, the CID of the second response
     *@param attestationIndex1, the index of the attestation for the first response within subgraphBridgeProposals
     *@param attestationIndex2, the index of the attestation for the second response within subgraphBridgeProposals
     */
    function createQueryDispute(
        bytes32 subgraphBridgeID,
        bytes32 requestCID,
        bytes32 responseCID1,
        bytes32 responseCID2,
        uint256 attestationIndex1,
        uint256 attestationIndex2
    ) internal returns (bytes32 disputeID1, bytes32 disputeID2) {
        require(
            subgraphBridges[subgraphBridgeID].responseDataOffset != 0,
            "query bridge doesn't exist"
        );

        SubgraphBridgeProposals storage proposals = subgraphBridgeProposals[
            subgraphBridgeID
        ][requestCID];

        require(
            proposals.stake[responseCID1].totalStake.attestationStake > 0,
            "responseCID1 doesn't exist"
        );
        require(
            proposals.stake[responseCID2].totalStake.attestationStake > 0,
            "responseCID2 doesn't exist"
        );

        require(
            responseCID1 != responseCID2,
            "responseCID1 and responseCID2 are the same"
        );

        bytes memory attestationBytes1 = proposals
            .responseProposals[attestationIndex1]
            .attestationData;

        bytes memory attestationBytes2 = proposals
            .responseProposals[attestationIndex2]
            .attestationData;

        // open a dispute in the dispute manager contract
        (bytes32 _disputeID1, bytes32 _disputeID2) = IDisputeManager(
            theGraphDisputeManager
        ).createQueryDisputeConflict(attestationBytes1, attestationBytes2);

        // push the disputeIDs to the disputeID array
        queryDisputes[requestCID].push(_disputeID1);
        queryDisputes[requestCID].push(_disputeID2);

        // emit a SubgrapuQueryDisputed event for both disputes
        emit SubgraphQueryDisputeCreated(
            subgraphBridgeID,
            requestCID,
            _disputeID1
        );

        emit SubgraphQueryDisputeCreated(
            subgraphBridgeID,
            requestCID,
            _disputeID2
        );
        return (_disputeID1, _disputeID2);
    }

    /**
     *@notice this function checks if a query is being disputed
     *@param requestCID the requestCID of the query
     *@return true if the query is being disputed, false if not
     */
    function isQueryDisputed(bytes32 requestCID) public view returns (bool) {
        for (uint256 i = 0; i < queryDisputes[requestCID].length; i++) {
            if (
                IDisputeManager(theGraphDisputeManager).isDisputeCreated(
                    queryDisputes[requestCID][i]
                )
            ) {
                return true;
            }
        }
        return false;
    }

    /**
     @notice this function is used to pin a blockhash to a blocknumber
     @param blockNumber the blocknumber to pin the blockhash to
     */
    function pinBlockHash(uint256 blockNumber) public {
        require(
            blockNumber > block.number - 256,
            "Pinned block must be within the last 256 blocks"
        );
        require(
            // pinnedBlocks[blockhash(blockNumber)] == 0,
            pinnedBlocks[blockNumber] == 0,
            "pinBlockHash: already pinned!"
        );
        pinnedBlocks[blockNumber] = blockhash(blockNumber);
    }

    //TODO: HANDLE ALL DATA TYPES
    /**
     *@notice this function takes in a subgraphBridgeID, a requestCID, and a responseCID and extracts the data from the responseCID and stores it in the subgraphBridgeData mapping
     *@param subgraphBridgeID, the ID of the subgraph bridge
     *@param requestCID, the CID of the request
     *@param response, the response string from the subgraph
     */
    function _extractData(
        bytes32 subgraphBridgeID,
        bytes32 requestCID,
        string calldata response
    ) private {
        BridgeDataType _type = subgraphBridges[subgraphBridgeID]
            .responseDataType;

        if (_type == BridgeDataType.UINT) {
            subgraphBridgeData[subgraphBridgeID][requestCID] = abi.encodePacked(
                _uintFromString(
                    response,
                    subgraphBridges[subgraphBridgeID].responseDataOffset
                )
            );
        } else if (_type == BridgeDataType.ADDRESS) {
            subgraphBridgeData[subgraphBridgeID][requestCID] = abi.encodePacked(
                _addressFromString(
                    response,
                    subgraphBridges[subgraphBridgeID].responseDataOffset
                )
            );
        } else if (_type == BridgeDataType.BYTES32) {
            subgraphBridgeData[subgraphBridgeID][requestCID] = abi.encodePacked(
                _bytes32FromString(
                    response,
                    subgraphBridges[subgraphBridgeID].responseDataOffset
                )
            );
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
    function queryAndResponseMatchAttestation(
        bytes32 blockHash,
        bytes32 subgraphBridgeID,
        string calldata response,
        IDisputeManager.Attestation memory attestation
    ) public view returns (bool) {
        require(
            attestation.requestCID ==
                _generateQueryRequestCID(blockHash, subgraphBridgeID),
            "queryAndResponseMatchAttestation: RequestCID Doesn't Match"
        );
        require(
            attestation.responseCID == keccak256(abi.encodePacked(response)),
            "queryAndResponseMatchAttestation: ResponseCID Doesn't Match"
        );
        require(
            subgraphBridges[subgraphBridgeID].subgraphDeploymentID ==
                attestation.subgraphDeploymentID,
            "queryAndResponseMatchAttestation: SubgraphDeploymentID Doesn't Match"
        );
        return true;
    }

    /**
     * @dev Parse the bytes attestation into a struct from `_data`.
     * @return Attestation struct
     */
    function parseAttestation(bytes memory _data)
        public
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
     *@dev this function generates the requestCID for the query at a blocknumber
     *@param _blockhash, the blockchash we are querying
     *@param _subgraphBridgeId, the id of the subgraphBridge
     *@return the keccak256 hash of the request
     */
    function _generateQueryRequestCID(
        bytes32 _blockhash,
        bytes32 _subgraphBridgeId
    ) public view returns (bytes32) {
        SubgraphBridge storage bridge = subgraphBridges[_subgraphBridgeId];

        bytes memory firstChunk = bridge.queryFirstChunk;
        bytes memory blockHash = toHexBytes(_blockhash);
        bytes memory lastChunk = bridge.queryLastChunk;
        return keccak256(bytes.concat(firstChunk, blockHash, lastChunk));
    }
}
