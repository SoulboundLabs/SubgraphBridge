// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
pragma abicoder v2;

import "forge-std/Vm.sol";
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
    // bytes32 public blockHash1 =
    //     0xeee517bc8c2cdaf7b1a122161223fd9d29d25f9250b071c964d508c5a9cb0ee3;
    bytes32 public blockHash1 = 0xb1bb1d7fb701542814eea2d3603c4c04edaa1cfcdda36e61aecadb377662bf78;
    uint256 public blockNumber1 = 187790336;
    bytes32 public subgraphDeploymentId = 0x13ac05d684e410ba8cddd8071bf10625cea68aef392869ed00d2f99511e1b681;

    // bytes32 public requestCID1 =
    //     0x200d785a4e650a6d55daec459392da7c1e22a3304710221a0b807e2260626aca;
    bytes32 public requestCID1 = 0x42a1d43adc2cfe2b6ad5ce6d67050fe9ff7b802643bb430129cfae66fc7a4513;

    bytes32 public responseCID1 = 0xb906bbe7f925398dc40fa24c50bd924b460cc7affb2b9d733429d41bf6b3d7a8;
        

    // @notice Attestation Data
    bytes32 public r =
        0xd02535771e343077148fa9d71081f20278df24e2afcf7344da84127b776abe20;
    bytes32 public s =
       0x1975521845c813f13bb07cb3e4a26db4fb1058c67a67805310f4c79ddf76c392;
    uint8 public v = 28;

    string public response1 = '{"data":{"deposit":{"collateral":"2000000000000000000"}}}';

        

    // string public response1 = '{"data":{"outboxEntries":[],"outboxOutputs":[{"id":"0x00081e32a232df4807ea4c7fc55fe066488451eb168226b692310aa587b7599e-107","destAddr":"0x67b5504e212131241014e9ce952bfee8389ef391","l2Sender":"0x67b5504e212131241014e9ce952bfee8389ef391","path":"10660"},{"id":"0x000cc08669e83a2be52a6cdcf11f5023f0acfa510dad0696c4c6963d25c3c0e9-119","destAddr":"0x32b6bb6526216e53f2f4df700ee872bed90c8335","l2Sender":"0x32b6bb6526216e53f2f4df700ee872bed90c8335","path":"14310"},{"id":"0x000d5de27eb1e984744868e290b2642e56fed4bc64e2cb2e3be4d017e302c985-20","destAddr":"0x8d68c89b98f18820d6c020c561384467901014d5","l2Sender":"0x8d68c89b98f18820d6c020c561384467901014d5","path":"12286"},{"id":"0x0014379278fc961f7025d9f3697baa5c488cb9c980635dde2076062e4c1f1f17-33","destAddr":"0x91d7cf4b01eb26b0348560dfc60377b55e87bc5e","l2Sender":"0x91d7cf4b01eb26b0348560dfc60377b55e87bc5e","path":"16085"},{"id":"0x0017568be5b426c8c375213ae670d8350fa32fb69bd35ecc01329ee2cf00939b-165","destAddr":"0x518e3acd5e3af36daa02999cd8c656b11413f31f","l2Sender":"0x518e3acd5e3af36daa02999cd8c656b11413f31f","path":"16635"}]}}';

    
    bytes32 public extractedResponseData =
         0x7b646174613a207b6465706f7369743a207b636f6c6c61746572616c3a200000;
         //0x044e86abf512ff8914f03da2d6ac41725b0ad09e56cef7326bb5ca4a173f35db;

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

    // vitalik address for testing and Arbitrum sepolia contracts
   
     address staking = 0x00669A4CF01450B64E8A2A20E9b1FCB71E61eF03;

     address dispute = 0x0Ab2B043138352413Bb02e67E626a70320E3BD46;

    address public vitalik = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    // mainnet

    // address staking = 0xF55041E37E12cD407ad00CE2910B8269B01263b9;

    // address dispute = 0x97307b963662cCA2f7eD50e38dCC555dfFc4FB0b;

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

        bytes32 newBlockHash = blockhash(blockNumber1);
        console2.logBytes32(newBlockHash);
        console2.logBytes32(bridge._generateQueryRequestCID(newBlockHash, bridgeId));
    }

    function testIfDeployed() public view {
        assert(
             0x865365C425f3A593Ffe698D9c4E6707D14d51e08 ==
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
