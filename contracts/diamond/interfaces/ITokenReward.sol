// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITokenReward {

    struct StakePoolInfo {
        uint256 totalStaked;
        uint256 tokenPerBlock;        //award per block
        uint256 lastRewardBlock;   // Last block number that Tokens distribution occurs.
        uint256 accTokenPerShare;    // Accumulated Tokens per share, times 1e12. See below.
        uint256 totalReward;
        uint256 reserves;
    }

    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 pendingReward; // User pending reward
        //
        // We do some fancy math here. Basically, any point in time, the amount of Tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTokenPerShare) - user.rewardDebt + user.rewardPending
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User's `pendingReward` gets updated.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    function updateTokenPerBlock(uint256 tokenPerBlock) external;

    function addReserves(uint256 amount) external;

    function poolInfo() external view returns (StakePoolInfo memory) ;

    function pendingToken(address _account) external view returns (uint256);
}
