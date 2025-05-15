// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title MockWorldID
/// @notice Mock implementation of the World ID interface for testing
contract MockWorldID {
    bool public shouldRevert = true;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function verifyProof(uint256, uint256, uint256, uint256, uint256, uint256[8] calldata) external view {
        if (shouldRevert) {
            revert("Revert on verify");
        }
    }
}
