// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/SubgraphBridge.sol";
import "../src/dependencies/TheGraph/IDisputeManager.sol";
import "../src/MockContracts/MockDispute.sol";

contract SubgraphBridgeTest is Test {
    // @notice Contracts
    SubgraphBridgeManager public bridge;
    SubgraphBridgeManager.SubgraphBridge public sampleBridge;
    // @notice SubgraphBridge Config
    bytes public firstChunk =
        hex"7b227175657279223a227b5c6e2020626f6e6465724164646564732866697273743a2031302c20626c6f636b3a207b686173683a205c22";
    bytes public lastChunk =
        hex"5c227d29207b5c6e2020202069645c6e20207d5c6e7d5c6e222c227661726961626c6573223a7b7d7d";
    bytes32 public blockHash1 =
        0xeee517bc8c2cdaf7b1a122161223fd9d29d25f9250b071c964d508c5a9cb0ee3;
    uint256 public blockNumber1 = 15984538;
    bytes32 public subgraphDeploymentId =
        0xe38339f1ed253e87deacd7d21ada20bb414fa9958d3ddd80f1e39aa724f76224;

    bytes32 public requestCID1 =
        0x200d785a4e650a6d55daec459392da7c1e22a3304710221a0b807e2260626aca;
    bytes32 public responseCID1 =
        0x2ba2ff1138e3b6b95ca8ddc5fdeb67604ba15e35571f4e0adaa7b3a6e7d80284;

    // @notice Attestation Data
    bytes32 public r =
        0xc67476e32e2121de62e78558392246c6b48e7ce505a051b40694ebf6a929bbb7;
    bytes32 public s =
        0x2c3c887a657777cdf5f907fc48fc92f229a60ce9bad7b27f1ed4819dbaa7c38f;
    uint8 public v = 28;

    string public response1 =
        '{"data":{"bonderAddeds":[{"id":"0x044e86abf512ff8914f03da2d6ac41725b0ad09e56cef7326bb5ca4a173f35db60"},{"id":"0x0a9209bfa2cfe74d7b81901c422766d65b43c2452ebe3c99319d14cad5a78301127"},{"id":"0x0f3f94aad9213eccee4540428c1cc0a315ce92b25af8dfe9d48b49dbb33a09a1111"},{"id":"0x2ca87cf0eb5259ca22cd015e6d5f25b92800a98d665d3ad009920da2c38020c2107"},{"id":"0x3aef54912826dfad2198871f1cd1083cc59cd5987f36019dc3cfb0c9d01faf2716"},{"id":"0x3eb7e67c64e6f1b2b130ff3b718f7b80634b090fb830d1463c76b5be7325044e88"},{"id":"0x3eb7e67c64e6f1b2b130ff3b718f7b80634b090fb830d1463c76b5be7325044e89"},{"id":"0x5e39acf2fbfaf76f862da9d5cb631984d79b1f9c5ed53d4935990cce32e8b618136"},{"id":"0x6cb5869dac39393c4717439eb4a49e5f0ea12fb466f2d18a1bfa10de307cf83942"},{"id":"0x889eee552461cff761f2954834adbc1e6714c6ec7bb74e6d4c84049fc7a6d9fc15"}]}}';

    bytes32 public extractedResponseData =
        0x044e86abf512ff8914f03da2d6ac41725b0ad09e56cef7326bb5ca4a173f35db;

    bytes attestationBytes =
        abi.encodePacked(
            requestCID1,
            responseCID1,
            subgraphDeploymentId,
            r,
            s,
            v
        );

    uint16 public responseDataOffset = 32;
    SubgraphBridgeManagerHelpers.BridgeDataType public bridgeDataType =
        SubgraphBridgeManagerHelpers.BridgeDataType.BYTES32;

    uint8 proposalFreezePeriod = 69;
    uint256 minimumSlashableGRT = 100;
    uint8 disputeResolutionWindow = 100; // 100 blocks or 25 minutes
    uint8 resolutionThresholdSlashableGRT = 50;
    uint8 resolutionThresholdExternalStake = 0;
    address stakingToken = address(0);

    bytes32 public bridgeId;

    // vitalik address for testing
    address public vitalik = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    address staking = 0xF55041E37E12cD407ad00CE2910B8269B01263b9;

    address dispute = 0x97307b963662cCA2f7eD50e38dCC555dfFc4FB0b;

    function setUp() public {
        bridge = new SubgraphBridgeManager(staking, dispute);

        sampleBridge = SubgraphBridgeManagerHelpers.SubgraphBridge(
            firstChunk,
            lastChunk,
            bridgeDataType,
            subgraphDeploymentId,
            proposalFreezePeriod,
            responseDataOffset,
            minimumSlashableGRT
        );

        bridge.createSubgraphBridge(sampleBridge);

        bridgeId = bridge._subgraphBridgeID(sampleBridge);

        bridge.pinBlockHash(blockNumber1);
    }

    function testIfDeployed() public view {
        assert(
            0xF55041E37E12cD407ad00CE2910B8269B01263b9 ==
                bridge.theGraphStaking()
        );
    }

    function testCreateRequestCID() public {
        bytes32 generatedRequestCID = bridge._generateQueryRequestCID(
            blockHash1,
            bridgeId
        );
        assertEq(requestCID1, generatedRequestCID);
    }

    function testQueryAndResponseMatchAttestation() public {
        IDisputeManager.Attestation memory attestation = IDisputeManager
            .Attestation(
                requestCID1,
                responseCID1,
                subgraphDeploymentId,
                r,
                s,
                v
            );

        assertEq(
            bridge.queryAndResponseMatchAttestation(
                blockhash(blockNumber1),
                bridgeId,
                response1,
                attestation
            ),
            true
        );
    }

    function testParseAttestation() public {
        IDisputeManager.Attestation memory attestation = IDisputeManager
            .Attestation(
                requestCID1,
                responseCID1,
                subgraphDeploymentId,
                r,
                s,
                v
            );

        bytes32 attestationHash = keccak256(abi.encode(attestation));
        bytes32 parsedAttestationHash = keccak256(
            abi.encode(bridge.parseAttestation(attestationBytes))
        );

        assertEq(attestationHash, parsedAttestationHash);

        bytes
            memory rawHexAttestation = hex"200d785a4e650a6d55daec459392da7c1e22a3304710221a0b807e2260626aca2ba2ff1138e3b6b95ca8ddc5fdeb67604ba15e35571f4e0adaa7b3a6e7d80284e38339f1ed253e87deacd7d21ada20bb414fa9958d3ddd80f1e39aa724f76224c67476e32e2121de62e78558392246c6b48e7ce505a051b40694ebf6a929bbb72c3c887a657777cdf5f907fc48fc92f229a60ce9bad7b27f1ed4819dbaa7c38f1c";

        bytes32 rawAttestationHash = keccak256(
            abi.encode(bridge.parseAttestation(rawHexAttestation))
        );

        assertEq(attestationHash, rawAttestationHash);
    }

    function postSubgraphResponse() public {
        // should work
        bridge.postSubgraphResponse(
            blockNumber1,
            bridgeId,
            response1,
            attestationBytes
        );
    }

    function testPostSubgraphResponse() public {
        // should revert if we try to use a non-existent query bridge id
        bytes32 badBridgeId = keccak256("hey");
        vm.expectRevert("query bridge doesn't exist");
        bridge.postSubgraphResponse(
            blockNumber1,
            badBridgeId,
            response1,
            attestationBytes
        );

        // if we submit an invalid attestation it should revert
        vm.expectRevert("Attestation must be 161 bytes long");
        bridge.postSubgraphResponse(
            blockNumber1,
            bridgeId,
            response1,
            bytes.concat(attestationBytes, "testing")
        );

        // if we submit an invalid requestCID it should revert
        bytes memory invalidRequest = abi.encodePacked(
            keccak256("invalidRequest"),
            responseCID1,
            subgraphDeploymentId,
            r,
            s,
            v
        );
        vm.expectRevert(
            "queryAndResponseMatchAttestation: RequestCID Doesn't Match"
        );
        bridge.postSubgraphResponse(
            blockNumber1,
            bridgeId,
            response1,
            invalidRequest
        );

        // if we submit an invalid response it should revert
        bytes memory invalidResponse = abi.encodePacked(
            requestCID1,
            keccak256("invalidResponse"),
            subgraphDeploymentId,
            r,
            s,
            v
        );
        vm.expectRevert(
            bytes("queryAndResponseMatchAttestation: ResponseCID Doesn't Match")
        );
        bridge.postSubgraphResponse(
            blockNumber1,
            bridgeId,
            response1,
            invalidResponse
        );

        // if we submit a invalid subgraphDeploymentId it should revert
        bytes memory invalidSubgraphDeploymentID = abi.encodePacked(
            requestCID1,
            responseCID1,
            keccak256("invalidSubgraphDeploymentID"),
            r,
            s,
            v
        );
        vm.expectRevert(
            "queryAndResponseMatchAttestation: SubgraphDeploymentID Doesn't Match"
        );
        bridge.postSubgraphResponse(
            blockNumber1,
            bridgeId,
            response1,
            invalidSubgraphDeploymentID
        );

        vm.expectRevert("query bridge doesn't exist");
        bridge.postSubgraphResponse(
            blockNumber1,
            keccak256("invalidBridgeId"),
            response1,
            attestationBytes
        );

        postSubgraphResponse();
    }

    function certifySubgraphResponse() public {
        vm.expectRevert("proposal count must be at least 1");
        bridge.certifySubgraphResponse(bridgeId, response1, attestationBytes);
        postSubgraphResponse();

        vm.expectRevert("proposal still frozen");
        bridge.certifySubgraphResponse(bridgeId, response1, attestationBytes);

        vm.roll(block.number + 100);
        bridge.certifySubgraphResponse(bridgeId, response1, attestationBytes);

        emit log_bytes(bridge.subgraphBridgeData(bridgeId, requestCID1));

        assertEq(
            keccak256(bridge.subgraphBridgeData(bridgeId, requestCID1)),
            keccak256(abi.encodePacked(extractedResponseData))
        );
    }

    function testDisputeCreation() public {
        string memory response2 = "invalidResponse";

        bytes32 responseCID2 = keccak256(bytes(response2));

        bytes memory mockStakingData = vm.getCode("MockStaking.sol");

        bytes memory mockDisputeData = vm.getDeployedCode("MockDispute.sol");

        // etch the staking contract code
        vm.etch(staking, mockStakingData);
        emit log_string("Updated code for the staking contract");
        vm.etch(dispute, mockDisputeData);
        emit log_string("Updated code for the dispute manager");

        emit log_uint(
            IStaking(staking).getIndexerStakedTokens(
                0x583249CF83598A03eB2bB17559932FBD5EE67C59 //attestation indexer
            )
        );

        bytes memory invalidResponseAttestation = abi.encodePacked(
            requestCID1,
            responseCID2,
            subgraphDeploymentId,
            r,
            s,
            v
        );

        bridge.postSubgraphResponse(
            blockNumber1,
            bridgeId,
            response1,
            attestationBytes
        );

        bridge.postSubgraphResponse(
            blockNumber1,
            bridgeId,
            response2,
            invalidResponseAttestation
        );
        vm.expectRevert(
            "certifySubgraphResponse: There is a query dispute for this request"
        );
        bridge.certifySubgraphResponse(
            bridgeId,
            response2,
            invalidResponseAttestation
        );

        // simulate the resolution of the disputes
        MockDispute(dispute).disputeResolve();

        vm.roll(block.number + 100);

        // this should work because there isn't a dispute open
        bridge.certifySubgraphResponse(bridgeId, response1, attestationBytes);
    }

    function testCertifySubgraphResponse() public {
        certifySubgraphResponse();
    }
}
