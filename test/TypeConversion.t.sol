// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SubgraphBridgeHelpers.sol";

contract TypeConversion is Test {
    SubgraphBridgeManagerHelpers public helpers;

    // uint
    string public numberString = "1234567890";
    bytes public numberBytes = abi.encodePacked(uint256(1234567890));

    // bytes32
    string public bytes32String =
        "0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8";
    bytes32 public bytes32Bytes =
        0x1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8;

    // address
    string public addressString = "0x807a1752402D21400D555e1CD7f175566088b955";
    address public addressBytes = 0x807a1752402D21400D555e1CD7f175566088b955;

    function setUp() public {
        helpers = new SubgraphBridgeManagerHelpers();
    }

    function testConvertUint() public {
        // uint256 result = helpers._uintFromString(numberString, 0);
        uint256 result = helpers.st2num(numberString);
        assertEq(abi.encodePacked(result), numberBytes);
    }

    function testConvertBytes32() public {
        bytes32 result = helpers._bytes32FromString(bytes32String, 2);
        assertEq(abi.encodePacked(result), abi.encodePacked(bytes32Bytes));
    }

    function testConvertAddress() public {
        address result = helpers._addressFromString(addressString, 0);
        assertEq(abi.encodePacked(result), abi.encodePacked(addressBytes));
    }

    function testAddressFromString() public {
        address result = helpers._addressFromString(addressString, 0);
        assertEq(abi.encodePacked(result), abi.encodePacked(addressBytes));
    }
}
