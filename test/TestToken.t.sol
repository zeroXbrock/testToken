// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TestToken} from "../src/TestToken.sol";

contract TestTokenTest is Test {
    TestToken public token;

    function setUp() public {
        token = new TestToken(1000000);
    }

    function test_transferFrom() public {
        vm.prank(address(42));
        token.transferFrom(address(this), address(42), 100);
        assertEq(token.balanceOf(address(this)), 1000000 - 100);
        assertEq(token.balanceOf(address(42)), 100);
    }
}
