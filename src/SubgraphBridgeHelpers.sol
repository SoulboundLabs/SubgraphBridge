pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

// we are putting all of the internal and internal functions in this contract

contract SubgraphBridgeManagerHelpers {
    // Attestation size is the sum of the receipt (96) + signature (65)
    uint256 internal constant ATTESTATION_SIZE_BYTES =
        RECEIPT_SIZE_BYTES + SIG_SIZE_BYTES;
    uint256 internal constant RECEIPT_SIZE_BYTES = 96;

    uint256 internal constant SIG_R_LENGTH = 32;
    uint256 internal constant SIG_S_LENGTH = 32;
    uint256 internal constant SIG_V_LENGTH = 1;
    uint256 internal constant SIG_R_OFFSET = RECEIPT_SIZE_BYTES;
    uint256 internal constant SIG_S_OFFSET = RECEIPT_SIZE_BYTES + SIG_R_LENGTH;
    uint256 internal constant SIG_V_OFFSET =
        RECEIPT_SIZE_BYTES + SIG_R_LENGTH + SIG_S_LENGTH;
    uint256 internal constant SIG_SIZE_BYTES =
        SIG_R_LENGTH + SIG_S_LENGTH + SIG_V_LENGTH;

    uint256 internal constant UINT8_BYTE_LENGTH = 1;
    uint256 internal constant BYTES32_BYTE_LENGTH = 32;
    uint256 internal constant BLOCKHASH_LENGTH = 66;

    uint256 MAX_UINT_256 =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // stored in mapping where (ID == attestation.requestCID)
    struct SubgraphBridgeProposals {
        // {attestation.responseCID} -> {stake}
        mapping(bytes32 => BridgeStake) stake;
        BridgeStakeTokens totalStake;
        uint256 proposalCount;
    }

    struct BridgeStake {
        BridgeStakeTokens totalStake;
        mapping(address => BridgeStakeTokens) accountStake;
    }

    struct BridgeStakeTokens {
        uint256 attestationStake; // Slashable GRT staked by indexers via the staking contract
        uint256 tokenStake; // GRT staked by oracles through Subgraph Bridge contract
    }

    // TODO: Create a function to decode this data.
    enum BridgeDataType {
        ADDRESS,
        BYTES32,
        UINT
        // todo: string
    }

    // TODO: Maybe combine first and last chunk of the query into a single bytes value, and store the split location somewhere else.
    struct SubgraphBridge {
        bytes queryFirstChunk; // the first bit of the query up to where the blockhash starts
        bytes queryLastChunk; // the last bit of the query from where the blockhash ends to the end of query
        uint16 responseDataOffset; // index where the data starts in the response string
        // NOTE: Not needed anymore now that we have the first and last chunk pattern.
        // uint16 blockHashOffset; // where the pinned block hash starts in the query string
        BridgeDataType responseDataType; // data type to be extracted from graphQL response string
        bytes32 subgraphDeploymentID; // subgraph being queried

        // dispute handling config
        uint8 proposalFreezePeriod; // undisputed queries can only be executed after this many blocks
        uint8 minimumSlashableGRT; // minimum slashable GRT staked by indexers in order for undisputed proposal to pass
        uint8 minimumExternalStake; // minimum external tokens staked in order for undisputed proposal to pass
        uint8 disputeResolutionWindow; // how many blocks it takes for disputes to be settled (0 indicates no dispute resolution)
        uint8 resolutionThresholdSlashableGRT; // (30-99) percent of slashable GRT required for dispute resolution
        uint8 resolutionThresholdExternalStake; // (30-99) percentage of external stake required for dispute resolution
        address stakingToken; // erc20 token for external staking
    }

    //TODO: Update this to hash something important now that query template is different
    function hashQueryTemplate(string memory queryTemplate)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(queryTemplate));
    }

    function _subgraphBridgeID(SubgraphBridge memory subgraphBridge)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(subgraphBridge));
    }

    function _bytes32FromString(string calldata fullString, uint16 dataOffset)
        public
        pure
        returns (bytes32)
    {
        string memory blockHashSlice = string(
            fullString[dataOffset:dataOffset + 64]
        );
        return _bytes32FromHex(blockHashSlice);
    }

    function _uintFromString(string calldata str, uint256 offset)
        public
        view
        returns (uint256)
    {
        (uint256 val, ) = _uintFromByteString(bytes(str), offset);
        return val;
    }

    // takes a full query string or response string and extracts a uint of unknown length beginning at the specified index
    function _uintFromByteString(bytes memory bString, uint256 offset)
        public
        view
        returns (uint256 value, uint256 depth)
    {
        bytes1 char = bString[offset];
        bool isEscapeChar = (char == 0x7D || char == 0x2C || char == 0x22); // ,}"
        if (isEscapeChar) {
            return (0, 0);
        }

        bool isDigit = (uint8(char) >= 48) && (uint8(char) <= 57); // 0-9
        require(isDigit, "invalid char");

        (uint256 trailingVal, uint256 trailingDepth) = _uintFromByteString(
            bString,
            offset + 1
        );
        return (
            trailingVal + (uint8(char) - 48) * 10**(trailingDepth),
            trailingDepth + 1
        );
    }

    // Convert an hexadecimal character to raw byte
    function _fromHexChar(uint8 c) public pure returns (uint8 _rawByte) {
        if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
            return 10 + c - uint8(bytes1("a"));
        }
    }

    // Convert hexadecimal string to raw bytes32
    function _bytes32FromHex(string memory s)
        public
        pure
        returns (bytes32 result)
    {
        bytes memory ss = bytes(s);
        require(ss.length == 64, "length of hex string must be 64");
        bytes memory bytesResult = new bytes(32);
        for (uint256 i = 0; i < ss.length / 2; ++i) {
            bytesResult[i] = bytes1(
                _fromHexChar(uint8(ss[2 * i])) *
                    16 +
                    _fromHexChar(uint8(ss[2 * i + 1]))
            );
        }

        assembly {
            result := mload(add(bytesResult, 32))
        }
    }

    /**
     * @dev Parse a uint8 from `_bytes` starting at offset `_start`.
     * @return uint8 value
     */
    function _toUint8(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint8)
    {
        require(
            _bytes.length >= (_start + UINT8_BYTE_LENGTH),
            "Bytes: out of bounds"
        );
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    /**
     * @dev Parse a bytes32 from `_bytes` starting at offset `_start`.
     * @return bytes32 value
     */
    function _toBytes32(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (bytes32)
    {
        require(
            _bytes.length >= (_start + BYTES32_BYTE_LENGTH),
            "Bytes: out of bounds"
        );
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }

    function toHex16 (bytes16 data) internal pure returns (bytes32 result) {
    result = bytes32 (data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000 |
          (bytes32 (data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64;
    result = result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000 |
          (result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32;
    result = result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000 |
          (result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16;
    result = result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000 |
          (result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8;
    result = (result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4 |
          (result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8;
    result = bytes32 (0x3030303030303030303030303030303030303030303030303030303030303030 +
           uint256 (result) +
           (uint256 (result) + 0x0606060606060606060606060606060606060606060606060606060606060606 >> 4 &
           // 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 7);
           0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 39);
    }

    function toHexBytes (bytes32 data) public pure returns (bytes memory) {
        return abi.encodePacked ("0x", toHex16 (bytes16 (data)), toHex16 (bytes16 (data << 128)));
    }
}
