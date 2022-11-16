// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SubgraphBridge.sol";

contract QueryCreation is Test {

    string public firstChunk = '{"query":"{\n  blocks(first: 10, block: {hash: \"';
    bytes32 public firstChunkKeccak = 0xb687ba2c120a9296cefaf2881c9b7d896b9a826a08ee80633b3a1140b12a7ff8;

    string public lastChunk = '\"}) {\n    id\n    number\n  }\n}","variables":{}}';
    bytes32 public lastChunkKeccak = 0xbbd94e461ba20804f06eea5ac0ec3d19c90fc7a7201f4977462a22bd9b6bcf96;

    bytes32 public blockHash = 0x39b93cc969f3ac620b896a128ee322dbba2e745fb2d6b8ba7218a275b9296648;
    bytes32 public requestCID = 0x088e483c247ca4554b207bffe11fa57082e1d4ace993301ecfafe7b269114e28;

    uint blockHashOffset =  strlen(firstChunk);

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
           0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 7);
    }

    function toHex (bytes32 data) public pure returns (string memory) {
        return string (abi.encodePacked ("0x", toHex16 (bytes16 (data)), toHex16 (bytes16 (data << 128))));
    }

    function testBlockHashToString() public {
     string memory blockHashAsString = "0x39b93cc969f3ac620b896a128ee322dbba2e745fb2d6b8ba7218a275b9296648";
     emit log_string(blockHashAsString);
    }

    function testKeccakStrings() public {
        string memory result = "request";

        bytes32 hash = keccak256(abi.encodePacked(result));

        assertEq(hash, 0x72859a6ae50aa97f593f23df1c78bb1fd78cfc493fcef64159d6486223196833);

        string memory words = "SomeOtherQuiteLongStringLetsJustSeeHowThisWorks";

        bytes32 wordHash = keccak256(abi.encodePacked(words));

        assertEq(wordHash, 0x34bba2d182f6f70dcdc5d2962126622c60729eea6534226f87b35dd2bd3045d4);

        bytes memory first = hex'7b227175657279223a227b5c6e2020626c6f636b732866697273743a2031302c20626c6f636b3a207b686173683a205c22';

        bytes32 firstChunkHash = keccak256(first);

        assertEq(firstChunkHash, firstChunkKeccak);

        bytes memory last = hex'5c227d29207b5c6e2020202069645c6e202020206e756d6265725c6e20207d5c6e7d222c227661726961626c6573223a7b7d7d';

        bytes32 lastChunkHash = keccak256(last);

        assertEq(lastChunkHash, lastChunkKeccak);
    }

    function testCreatingQuery() public {
        bytes memory first = hex'7b227175657279223a227b5c6e2020626c6f636b732866697273743a2031302c20626c6f636b3a207b686173683a205c22';

        bytes memory last = hex'5c227d29207b5c6e2020202069645c6e202020206e756d6265725c6e20207d5c6e7d5c6e222c227661726961626c6573223a7b7d7d';

        // TODO: WE NEED A FUNCTION THAT CAN TURN A BLOCK HASH INTO IT'S TEXT BYTES ENCODING
        bytes memory blockHashBytes = hex'3078333962393363633936396633616336323062383936613132386565333232646262613265373435666232643662386261373231386132373562393239363634386f';

        bytes memory combined = bytes.concat(first,blockHashBytes,last);

        bytes32 combinedHash = keccak256(combined);

        bytes memory onlineCombined = hex'7b227175657279223a227b5c6e2020626c6f636b732866697273743a2031302c20626c6f636b3a207b686173683a205c223078333962393363633936396633616336323062383936613132386565333232646262613265373435666232643662386261373231386132373562393239363634386f5c227d29207b5c6e2020202069645c6e202020206e756d6265725c6e20207d5c6e7d5c6e222c227661726961626c6573223a7b7d7d';

        assertEq(combined, onlineCombined);

        assertEq(combinedHash, keccak256(onlineCombined));

        // assertEq(combinedHash, 0x7c7661153902e08e05f1830562654324a58541af2e63c0c0b64d4120e4dece15);

        // assertEq(keccak256(onlineCombined), hex'7c7661153902e08e05f1830562654324a58541af2e63c0c0b64d4120e4dece15');
    }

}
