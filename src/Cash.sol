// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {ByteHasher} from "./libraries/ByteHasher.sol";
import {IWorldID} from "./interfaces/IWorldID.sol";

/// @title Cash
/// @author OnePay Team
/// @notice An ERC20 token that can be claimed by users who verify their identity using World ID
/// @dev This contract implements a basic UBI (Universal Basic Income) token that can be claimed
///      once per day by users who verify their identity using World ID's proof system
contract Cash is ERC20Upgradeable {
    using ByteHasher for bytes;

    /// @notice Thrown when a user attempts to claim tokens before the waiting period has elapsed
    error ClaimNotReady();

    /// @notice Thrown when a nullifier hash has already been used
    error InvalidNullifier();

    /// @notice Maps user addresses to their last claim timestamp
    /// @dev Used to enforce the waiting period between claims
    mapping(address user => uint256 timestamp) public lastClaimTimestamps;

    /// @notice Address of the World ID contract
    /// @dev Used for verifying proofs of identity
    IWorldID internal constant WORLD_ID = IWorldID(0x17B354dD2595411ff79041f930e491A4Df39A278);

    /// @notice Time required between claims (24 hours in seconds)
    uint256 internal constant CLAIM_WAIT_TIME_SECS = 86400;

    /// @notice Amount of tokens to mint per claim (1 token with 18 decimals)
    uint256 internal constant CLAIM_AMOUNT = 1 ether;

    /// @notice World ID group identifier
    /// @dev Represents the group of users eligible for verification
    uint256 internal constant GROUP_ID = 1;
    uint256 internal constant APP_ID = 1;

    /// @notice External nullifier hash used in the World ID verification
    /// @dev Prevents double-signaling across different applications
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 internal immutable EXTERNAL_NULLIFIER_HASH =
        abi.encodePacked(abi.encodePacked("app_49fe40f83cfcdf67b7ba716d37e927e4").hashToField(), "claim").hashToField();

    function initialize() public initializer {
        __ERC20_init("CASH", "Cash");
    }

    /// @notice Allows users to claim tokens after verifying their identity with World ID
    /// @param root The Merkle root of the World ID identity group
    /// @param nullifierHash A unique hash representing this specific proof
    /// @param proof Zero-knowledge proof data
    /// @return amount The amount of tokens claimed
    /// @dev Users can only claim once per CLAIM_WAIT_TIME_SECS period
    function claim(uint256 root, uint256 nullifierHash, uint256[8] calldata proof) public returns (uint256 amount) {
        // Check if the waiting period has elapsed since the last claim
        if (block.timestamp - lastClaimTimestamps[msg.sender] < CLAIM_WAIT_TIME_SECS) {
            revert ClaimNotReady();
        }

        // Verify the World ID proof
        WORLD_ID.verifyProof(
            root, GROUP_ID, abi.encodePacked(msg.sender).hashToField(), nullifierHash, EXTERNAL_NULLIFIER_HASH, proof
        );

        // Record the current timestamp to track when the user can claim again
        lastClaimTimestamps[msg.sender] = block.timestamp;

        // Mint tokens to the caller
        _mint(msg.sender, CLAIM_AMOUNT);

        return CLAIM_AMOUNT;
    }
}
