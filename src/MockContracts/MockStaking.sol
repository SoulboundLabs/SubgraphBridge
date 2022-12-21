// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;
pragma abicoder v2;

import "../dependencies/TheGraph/IStakingData.sol";

contract MockStaking {
    function getAllocation(address _allocationID)
        public
        view
        returns (IStakingData.Allocation memory)
    {
        return
            IStakingData.Allocation(
                0x583249CF83598A03eB2bB17559932FBD5EE67C59,
                0xe38339f1ed253e87deacd7d21ada20bb414fa9958d3ddd80f1e39aa724f76224,
                1000000000000000000,
                464,
                0,
                0,
                0,
                19779656285104043700
            );
    }

    function getIndexerStakedTokens(address _indexer)
        public
        view
        returns (uint256)
    {
        return 107584450891424155568368;
    }
}
