// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
pragma abicoder v2;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Cash} from "../src/Cash.sol";

contract DeployCash is Script {
    address constant ADMIN = 0x0b59A31154a0742DBb2623eB366f9cFaEAF11558;

    function run() external {
        vm.startBroadcast();

        // Deploy Cash contract
        address proxy = Upgrades.deployTransparentProxy("Cash.sol", ADMIN, abi.encode(Cash.initialize.selector));

        console.log("Cash deployed to:", address(proxy));

        vm.stopBroadcast();
    }
}
