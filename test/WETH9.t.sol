// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6;

import {Test, console} from "forge-std/Test.sol";
import {WETH9} from "../src/WETH9.sol";

contract WETHTest is Test {
    WETH9 public weth;

    function setUp() public {
        weth = new WETH9();
        weth.deposit{value: 1 ether}();
    }

    function test_transferFrom() public {
        vm.prank(address(42));
        weth.transferFrom(address(this), address(42), 100);
        assertEq(weth.balanceOf(address(this)), 1 ether - 100);
        assertEq(weth.balanceOf(address(42)), 100);
    }
}
