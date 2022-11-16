// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SubgraphBridge.sol";

contract QueryCreation is Test {

    // for first query test
    bytes32 public blockHash1 = 0xeee517bc8c2cdaf7b1a122161223fd9d29d25f9250b071c964d508c5a9cb0ee3;
    bytes public onlineBlockHash1 = hex'307865656535313762633863326364616637623161313232313631323233666439643239643235663932353062303731633936346435303863356139636230656533';
    bytes32 public requestCID1 = 0x200d785a4e650a6d55daec459392da7c1e22a3304710221a0b807e2260626aca;

    // for second query test
    bytes32 public blockHash2 = 0x5b1dc013f92873fe9017f28612ef67a5b141e83f75f036d9cb7c8e1b8ef805be;
    bytes public onlineBlockHash2 = hex'307835623164633031336639323837336665393031376632383631326566363761356231343165383366373566303336643963623763386531623865663830356265';
    bytes32 public requestCID2 = 0x294d2e09b8935ecec4294e6e3cf8f0f047877f6d5ec6f7ccaf53ba48ce8e1f74;

    // default query first chunk hex
    bytes public firstChunk = hex'7b227175657279223a227b5c6e2020626f6e6465724164646564732866697273743a2031302c20626c6f636b3a207b686173683a205c22';
    // default query last chunk hex
    bytes public lastChunk = hex'5c227d29207b5c6e2020202069645c6e20207d5c6e7d5c6e222c227661726961626c6573223a7b7d7d';

    bytes public totalQueryHex1 = hex'7b227175657279223a227b5c6e2020626f6e6465724164646564732866697273743a2031302c20626c6f636b3a207b686173683a205c223078656565353137626338633263646166376231613132323136313232336664396432396432356639323530623037316339363464353038633561396362306565335c227d29207b5c6e2020202069645c6e20207d5c6e7d5c6e222c227661726961626c6573223a7b7d7d';

    bytes public totalQueryHex2 = hex'7b227175657279223a227b5c6e2020626f6e6465724164646564732866697273743a2031302c20626c6f636b3a207b686173683a205c223078356231646330313366393238373366653930313766323836313265663637613562313431653833663735663033366439636237633865316238656638303562655c227d29207b5c6e2020202069645c6e20207d5c6e7d5c6e222c227661726961626c6573223a7b7d7d';

    // @dev I was just testing to see how strings are handled when abi encoding.
    function testKeccakStrings() public {
        string memory result = "request";

        bytes32 hash = keccak256(abi.encodePacked(result));

        assertEq(hash, 0x72859a6ae50aa97f593f23df1c78bb1fd78cfc493fcef64159d6486223196833);

        string memory words = "SomeOtherQuiteLongStringLetsJustSeeHowThisWorks";

        bytes32 wordHash = keccak256(abi.encodePacked(words));

        assertEq(wordHash, 0x34bba2d182f6f70dcdc5d2962126622c60729eea6534226f87b35dd2bd3045d4);
    }

    function testActualSubgraphQueries() public {
      bytes memory bytesBlockHash1 = toHexBytes(blockHash1);
      bytes memory generatedQuery1 = bytes.concat(firstChunk, bytesBlockHash1, lastChunk);
      assertEq(generatedQuery1, totalQueryHex1);
      assertEq(keccak256(generatedQuery1), requestCID1);

      bytes memory bytesBlockHash2 = toHexBytes(blockHash2);
      bytes memory generatedQuery2 = bytes.concat(firstChunk, bytesBlockHash2, lastChunk);
      assertEq(generatedQuery2, totalQueryHex2);
      assertEq(keccak256(generatedQuery2), requestCID2);
    }

    /*

    BELOW THIS LINE IS JUST HELPER FUNCTIONS:

    -----------------------------------------

    */


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

    function toHex (bytes32 data) public pure returns (string memory) {
        return string (abi.encodePacked ("0x", toHex16 (bytes16 (data)), toHex16 (bytes16 (data << 128))));
    }

    function toHexBytes (bytes32 data) public pure returns (bytes memory) {
        return abi.encodePacked ("0x", toHex16 (bytes16 (data)), toHex16 (bytes16 (data << 128)));
    }

}
