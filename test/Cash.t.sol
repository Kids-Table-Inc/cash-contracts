// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Cash} from "../src/Cash.sol";
import {MockWorldID} from "./mocks/MockWorldID.sol";

/// @title CashTest
/// @notice Test suite for the Cash token contract
contract CashTest is Test {
    // Constants for testing
    string constant APP_ID = "app_test_123";
    string constant ACTION = "claim";
    uint256 constant CLAIM_AMOUNT = 1 ether;
    uint256 constant CLAIM_WAIT_TIME_SECS = 86400; // 24 hours

    // Test accounts
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address admin = makeAddr("admin");

    // Contract instances
    Cash cash;
    MockWorldID mockWorldID;

    // Test data for World ID verification
    uint256 root = 123456789;
    uint256 nullifierHash = 987654321;
    uint256[8] proof;

    /// @notice Set up the test environment before each test
    function setUp() public {
        // Deploy mock World ID contract
        mockWorldID = new MockWorldID();

        // Deploy Cash contract with our mock World ID
        vm.etch(0x17B354dD2595411ff79041f930e491A4Df39A278, address(mockWorldID).code);

        // Deploy Cash contract
        address proxy = Upgrades.deployTransparentProxy("Cash.sol", admin, abi.encode(Cash.initialize.selector));
        cash = Cash(proxy);

        // Set up proof data (simplified for testing)
        for (uint256 i = 0; i < 8; i++) {
            proof[i] = i + 1;
        }

        // Give test accounts some ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    /// @notice Test basic ERC20 properties of the Cash token
    function testERC20Properties() public view {
        assertEq(cash.name(), "CASH");
        assertEq(cash.symbol(), "Cash");
        assertEq(cash.decimals(), 18);
        assertEq(cash.totalSupply(), 0);
    }

    /// @notice Test successful token claim
    function testSuccessfulClaim() public {
        // Set initial block timestamp to a known value
        uint256 startTime = 1000000;
        vm.warp(startTime);

        // Claim as Alice
        vm.prank(alice);
        uint256 claimedAmount = cash.claim(root, nullifierHash, proof);

        // Verify claim results
        assertEq(claimedAmount, CLAIM_AMOUNT);
        assertEq(cash.balanceOf(alice), CLAIM_AMOUNT);
        assertEq(cash.totalSupply(), CLAIM_AMOUNT);
    }

    /// @notice Test multiple users claiming tokens
    function testMultipleUsersClaim() public {
        // Set initial block timestamp to a known value
        uint256 startTime = 1000000;
        vm.warp(startTime);

        // Alice claims
        vm.prank(alice);
        cash.claim(root, nullifierHash, proof);

        // Bob claims with a different nullifier hash
        uint256 bobNullifierHash = nullifierHash + 1;
        vm.prank(bob);
        cash.claim(root, bobNullifierHash, proof);

        // Charlie claims with a different nullifier hash
        uint256 charlieNullifierHash = nullifierHash + 2;
        vm.prank(charlie);
        cash.claim(root, charlieNullifierHash, proof);

        // Verify balances
        assertEq(cash.balanceOf(alice), CLAIM_AMOUNT);
        assertEq(cash.balanceOf(bob), CLAIM_AMOUNT);
        assertEq(cash.balanceOf(charlie), CLAIM_AMOUNT);
        assertEq(cash.totalSupply(), CLAIM_AMOUNT * 3);
    }

    /// @notice Test that a user cannot claim twice within the waiting period
    function testCannotClaimTwiceWithinWaitingPeriod() public {
        // Set initial block timestamp to a known value
        uint256 startTime = 1000000;
        vm.warp(startTime);

        // First claim should succeed
        vm.prank(alice);
        cash.claim(root, nullifierHash, proof);

        // Try to claim again immediately (should fail)
        vm.prank(alice);
        vm.expectRevert(Cash.ClaimNotReady.selector);
        cash.claim(root, nullifierHash + 1, proof); // Use different nullifier hash

        // Advance time by almost 24 hours (just under the waiting period)
        vm.warp(startTime + CLAIM_WAIT_TIME_SECS - 1);

        // Claim should still fail
        vm.prank(alice);
        vm.expectRevert(Cash.ClaimNotReady.selector);
        cash.claim(root, nullifierHash + 2, proof); // Use different nullifier hash
    }

    /// @notice Test that a user can claim again after the waiting period
    function testCanClaimAgainAfterWaitingPeriod() public {
        // Set initial block timestamp to a known value
        uint256 startTime = 1000000;
        vm.warp(startTime);

        // First claim
        vm.prank(alice);
        cash.claim(root, nullifierHash, proof);
        assertEq(cash.balanceOf(alice), CLAIM_AMOUNT);

        // Advance time by exactly the waiting period
        vm.warp(startTime + CLAIM_WAIT_TIME_SECS);

        // Second claim should now succeed
        vm.prank(alice);
        cash.claim(root, nullifierHash + 1, proof); // Use different nullifier hash
        assertEq(cash.balanceOf(alice), CLAIM_AMOUNT * 2);
    }

    /// @notice Test that claim fails if World ID verification fails
    function testClaimFailsWithInvalidWorldIDProof() public {
        mockWorldID.setShouldRevert(true);

        // Claim should fail due to World ID verification
        vm.prank(alice);
        vm.expectRevert();
        cash.claim(root, nullifierHash, proof);

        // Verify no tokens were minted
        assertEq(cash.balanceOf(alice), 0);
        assertEq(cash.totalSupply(), 0);
    }

    /// @notice Test ERC20 transfer functionality
    function testERC20Transfers() public {
        // Set initial block timestamp to a known value
        uint256 startTime = 1000000;
        vm.warp(startTime);

        vm.prank(alice);
        cash.claim(root, nullifierHash, proof);

        // Alice transfers half her tokens to Bob
        vm.prank(alice);
        bool success = cash.transfer(bob, CLAIM_AMOUNT / 2);

        // Verify transfer results
        assertTrue(success);
        assertEq(cash.balanceOf(alice), CLAIM_AMOUNT / 2);
        assertEq(cash.balanceOf(bob), CLAIM_AMOUNT / 2);

        // Bob transfers some tokens to Charlie
        vm.prank(bob);
        success = cash.transfer(charlie, CLAIM_AMOUNT / 4);

        // Verify second transfer results
        assertTrue(success);
        assertEq(cash.balanceOf(alice), CLAIM_AMOUNT / 2);
        assertEq(cash.balanceOf(bob), CLAIM_AMOUNT / 4);
        assertEq(cash.balanceOf(charlie), CLAIM_AMOUNT / 4);
    }

    /// @notice Test ERC20 approval and transferFrom functionality
    function testERC20ApprovalAndTransferFrom() public {
        // Set initial block timestamp to a known value
        uint256 startTime = 1000000;
        vm.warp(startTime);

        vm.prank(alice);
        cash.claim(root, nullifierHash, proof);

        // Alice approves Bob to spend her tokens
        vm.prank(alice);
        bool success = cash.approve(bob, CLAIM_AMOUNT / 2);
        assertTrue(success);
        assertEq(cash.allowance(alice, bob), CLAIM_AMOUNT / 2);

        // Bob transfers tokens from Alice to Charlie
        vm.prank(bob);
        success = cash.transferFrom(alice, charlie, CLAIM_AMOUNT / 2);

        // Verify transferFrom results
        assertTrue(success);
        assertEq(cash.balanceOf(alice), CLAIM_AMOUNT / 2);
        assertEq(cash.balanceOf(charlie), CLAIM_AMOUNT / 2);
        assertEq(cash.allowance(alice, bob), 0);
    }
}
