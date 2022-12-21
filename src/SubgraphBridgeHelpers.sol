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
        ResponseProposal[] responseProposals;
        BridgeStakeTokens totalStake;
        uint256 proposalCount;
    }

    struct ResponseProposal {
        bytes32 responseCID;
        bytes attestationData;
        uint256 proposalBlockNumber;
    }

    struct BridgeStake {
        BridgeStakeTokens totalStake;
        mapping(address => BridgeStakeTokens) accountStake;
    }

    struct BridgeStakeTokens {
        uint256 attestationStake; // Slashable GRT staked by indexers via the staking contract
        uint256 tokenStake; // GRT staked by oracles through Subgraph Bridge contract
    }

    enum BridgeDataType {
        ADDRESS,
        BYTES32,
        UINT
        // todo: string
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
        pure
        returns (uint256)
    {
        return st2num(str[offset:]);
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

    function toHex16(bytes16 data) internal pure returns (bytes32 result) {
        result =
            (bytes32(data) &
                0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000) |
            ((bytes32(data) &
                0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >>
                64);
        result =
            (result &
                0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000) |
            ((result &
                0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >>
                32);
        result =
            (result &
                0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000) |
            ((result &
                0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >>
                16);
        result =
            (result &
                0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000) |
            ((result &
                0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >>
                8);
        result =
            ((result &
                0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >>
                4) |
            ((result &
                0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >>
                8);
        result = bytes32(
            0x3030303030303030303030303030303030303030303030303030303030303030 +
                uint256(result) +
                (((uint256(result) +
                    0x0606060606060606060606060606060606060606060606060606060606060606) >>
                    4) &
                    // 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 7);
                    0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) *
                39
        );
    }

    function toHexBytes(bytes32 data) public pure returns (bytes memory) {
        return
            abi.encodePacked(
                "0x",
                toHex16(bytes16(data)),
                toHex16(bytes16(data << 128))
            );
    }

    function _addressFromString(string memory str, uint256 start)
        public
        pure
        returns (address)
    {
        bytes memory b = bytes(str);
        uint256 result = 0;
        for (uint256 i = start; i < 42; i++) {
            uint256 c = uint8(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 16 + (c - 48);
            }
            if (c >= 65 && c <= 70) {
                result = result * 16 + (c - 55);
            }
            if (c >= 97 && c <= 102) {
                result = result * 16 + (c - 87);
            }
        }

        return address(uint160(result));
    }

    function st2num(string memory numString) public pure returns (uint256) {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i]; // the char byte
            uint8 uval = uint8(ival); // the char byte as a uint8
            uint256 jval = uval - uint256(0x30); // the char byte as a uint8 minus 0x30

            val += (uint256(jval) * (10**(exp - 1))); // multiply by the appropriate power of 10
        }
        return val;
    }
}
