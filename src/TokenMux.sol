// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestToken} from "./TestToken.sol";
import "./interfaces/IUniV3.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH9.sol";

contract TokenMux {
    mapping(uint8 => TestToken) public tokens;
    uint8 public numTokens;
    uint256 initialSupply;
    uint256 swapNonce;
    IUniV3Factory uniV3Factory;
    IWETH9 weth;
    INonfungiblePositionManager uniV3PositionManager;
    IUniV3Router uniV3Router;
    bool public wethPoolsReady;
    bool public tokenPoolsReady;

    constructor(
        uint8 _numTokens,
        uint256 _initialSupply,
        address _weth,
        address _uniV3Factory,
        address _uniV3PositionManager,
        address _uniV3Router
    ) {
        require(_numTokens >= 3, "numTokens must be >= 3");
        numTokens = _numTokens;
        initialSupply = _initialSupply;
        uniV3Factory = IUniV3Factory(_uniV3Factory);
        weth = IWETH9(_weth);
        uniV3PositionManager = INonfungiblePositionManager(
            _uniV3PositionManager
        );
        uniV3Router = IUniV3Router(_uniV3Router);

        // create tokens
        for (uint8 i = 0; i < _numTokens; i++) {
            tokens[i] = new TestToken(_initialSupply);
        }
    }

    /** make a pool between each token and WETH */
    function initWethPools() public {
        for (uint8 i = 0; i < numTokens; i++) {
            address pool = uniV3Factory.createPool(
                address(tokens[i]),
                address(weth),
                3000
            );
            IUniV3Pool(pool).initialize(79228162514264337593543950336);
        }
    }

    function mintWethPools() public {
        require(
            uniV3Factory.getPool(address(tokens[0]), address(weth), 3000) !=
                address(0),
            "token pools not initialized. Call initWethPools()"
        );
        uint256 weth_balance = weth.balanceOf(address(this));
        require(weth_balance >= numTokens, "insufficient WETH balance");
        uint256 amountDesired = (weth_balance / 2) / numTokens;
        for (uint8 i = 0; i < numTokens; i++) {
            address tokenA = address(tokens[i]);
            address tokenB = address(weth);
            (address token0, address token1) = tokenA < tokenB
                ? (tokenA, tokenB)
                : (tokenB, tokenA);
            MintParams memory params = MintParams({
                token0: token0,
                token1: token1,
                fee: 3000,
                tickLower: -887220,
                tickUpper: 887220,
                amount0Desired: amountDesired,
                amount1Desired: amountDesired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 1000
            });
            uniV3PositionManager.mint(params);
        }
        wethPoolsReady = true;
    }

    function initTokenPools() public {
        // make a pool between each token and the next token
        // A <-> B, B <-> C, C <-> D, ...
        for (uint8 i = 0; i < numTokens; i++) {
            address pool = uniV3Factory.createPool(
                address(tokens[i]),
                address(tokens[(i + 1) % numTokens]), // wrap around
                3000
            );
            IUniV3Pool(pool).initialize(79228162514264337593543950336);
        }
    }

    function mintTokenPools() public {
        require(
            uniV3Factory.getPool(
                address(tokens[0]),
                address(tokens[1]),
                3000
            ) != address(0),
            "token pools not initialized. Call initTokenPools()"
        );
        uint256 amountDesired = (initialSupply / numTokens) / 4;
        for (uint8 i = 0; i < numTokens; i++) {
            address tokenA = address(tokens[i]);
            address tokenB = address(tokens[(i + 1) % numTokens]);
            (address token0, address token1) = tokenA < tokenB
                ? (tokenA, tokenB)
                : (tokenB, tokenA);
            MintParams memory params = MintParams({
                token0: token0,
                token1: token1,
                fee: 3000,
                tickLower: -887220,
                tickUpper: 887220,
                amount0Desired: amountDesired,
                amount1Desired: amountDesired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp + 1000
            });
            uniV3PositionManager.mint(params);
        }
        tokenPoolsReady = true;
    }

    function getSwapParams(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address recipient
    ) internal view returns (ExactInputSingleParams memory) {
        return
            ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: recipient,
                deadline: block.timestamp + 1000,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
    }

    function pickSwapParams(
        uint256 amountIn
    ) internal view returns (ExactInputSingleParams memory) {
        // pick token index based on nonce
        // keeps the same tokenIdx for 4 swaps, then increments
        uint8 tokenIdx = uint8((swapNonce / 4) % numTokens);

        // cycle through trade types per call
        if (swapNonce % 4 == 0) {
            // swap WETH for token
            return
                getSwapParams(
                    address(weth),
                    address(tokens[tokenIdx]),
                    amountIn,
                    msg.sender
                );
        } else if (swapNonce % 4 == 1) {
            // swap token for WETH
            return
                getSwapParams(
                    address(tokens[tokenIdx]),
                    address(weth),
                    amountIn,
                    msg.sender
                );
        } else if (swapNonce % 4 == 2) {
            // swap token1 for token2
            uint8 tokenIdxNext = uint8((tokenIdx + 1) % numTokens);
            return
                getSwapParams(
                    address(tokens[tokenIdx]),
                    address(tokens[tokenIdxNext]),
                    amountIn,
                    msg.sender
                );
        } else {
            // swap token2 for token1
            uint8 tokenIdxNext = uint8((tokenIdx + 1) % numTokens);
            return
                getSwapParams(
                    address(tokens[tokenIdxNext]),
                    address(tokens[tokenIdx]),
                    amountIn,
                    msg.sender
                );
        }
    }

    function swap(uint256 amountIn) public {
        require(wethPoolsReady, "WETH pools not ready. Call mintWethPools()");
        require(
            tokenPoolsReady,
            "token pools not ready. Call mintTokenPools()"
        );

        ExactInputSingleParams memory params = pickSwapParams(amountIn);
        uint256 amountOut = uniV3Router.exactInputSingle(params);
        IERC20(params.tokenOut).transferFrom(
            params.recipient,
            address(this),
            amountOut
        );

        swapNonce++;
    }
}
