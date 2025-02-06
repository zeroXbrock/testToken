// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenMux} from "../src/TokenMux.sol";
import {IWETH9} from "../src/interfaces/IWETH9.sol";

contract TokenMuxTest is Test {
    TokenMux public mux;
    uint8 constant num_tokens = 3;
    uint256 constant initialSupply = 10000 ether;
    // pre-deployed contracts (from contender uniV3 scenario)
    address constant weth = 0xe8A78b327190CD689C4cfA2db9E85C7632eCFCbb;
    address constant factory = 0x849Ad8C2D3c1a7DA513c46DaE7dE870C0ec7391A;
    address constant router = 0x25D885c9C2542113714d89675DE69EB83EC70486;
    address constant positionManager =
        0x2B0E331f40D38C1138cF91dA6b74F7fAf961AE41;

    function setUp() public {
        require(weth.code.length > 0, "WETH contract is not deployed");
        require(factory.code.length > 0, "Factory contract is not deployed");
        require(router.code.length > 0, "Router contract is not deployed");
        require(
            positionManager.code.length > 0,
            "Position Manager contract is not deployed"
        );

        IWETH9(weth).deposit{value: 100 ether}();
        mux = new TokenMux(
            num_tokens,
            initialSupply,
            weth,
            factory,
            positionManager,
            router
        );
        IWETH9(weth).transfer(address(mux), 100 ether);
    }

    function test_tokens() public view {
        for (uint8 i = 0; i < num_tokens; i++) {
            assertEq(mux.tokens(i).balanceOf(address(mux)), initialSupply);
        }
    }

    function initPools() public {
        // these are split into 4 functions bc the first two use tons of gas
        mux.initTokenPools();
        mux.initWethPools();
        mux.mintTokenPools();
        mux.mintWethPools();
    }

    function test_initPools() public {
        initPools();
        // TODO: add assertions
    }

    function test_swap() public {
        initPools();
        mux.swap(1 ether);
        mux.swap(1 ether);
        mux.swap(1 ether);
        mux.swap(1 ether);
    }

    function test_initPoolsFailures() public {
        vm.expectRevert("WETH pools not ready. Call mintWethPools()");
        mux.swap(1 ether);

        // these are split into 4 functions bc the first two use tons of gas
        vm.expectRevert("token pools not initialized. Call initTokenPools()");
        mux.mintTokenPools();

        vm.expectRevert("token pools not initialized. Call initWethPools()");
        mux.mintWethPools();

        mux.initWethPools();
        mux.mintWethPools();
        vm.expectRevert("token pools not ready. Call mintTokenPools()");
        mux.swap(1 ether);
    }
}
