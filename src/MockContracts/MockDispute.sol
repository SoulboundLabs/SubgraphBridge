// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;
pragma abicoder v2;

import "../dependencies/TheGraph/IDisputeManager.sol";

contract MockDispute {
    bool public disputed1 = false;
    bool public disputed2 = false;

    function getAttestationIndexer(
        IDisputeManager.Attestation memory attestation
    ) public view returns (address) {
        return 0x583249CF83598A03eB2bB17559932FBD5EE67C59;
    }

    function createQueryDisputeConflict(
        bytes calldata _attestationData1,
        bytes calldata _attestationData2
    ) external returns (bytes32, bytes32) {
        disputed1 = true;
        disputed2 = true;
        return (keccak256(_attestationData1), keccak256(_attestationData2));
    }

    function isDisputeCreated(bytes32 _disputeID) external view returns (bool) {
        return disputed1 && disputed2;
    }

    function disputeResolve() public {
        disputed1 = false;
        disputed2 = false;
    }
}
