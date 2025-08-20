// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("LP");
    address swapper = makeAddr("swapper");

    int256 startingY;
    int256 startingX;

    int256 public expectedDeltaY;
    int256 public expectedDeltaX; // change in token balances
    int256 public actualDeltaX; // change in token balances
    int256 public actualDeltaY;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(pool.getPoolToken());
    }

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        outputWeth = bound(outputWeth, pool.getMinimumWethDepositAmount(), type(uint64).max);
        if (outputWeth > weth.balanceOf(address(this))) {
            return;
        }

        // ∆x = (β/(1-β)) * x
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWeth,
            poolToken.balanceOf(address(pool)),
            weth.balanceOf(address(pool))
        );
        if (poolTokenAmount > type(uint64).max) {
            return;
        }

        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));

        expectedDeltaY = int256(-1) * int256(outputWeth); // -1 because the pool is not gaining weth, instead is loosing cuz the swap is weth to poolToken
        expectedDeltaX = int256(
            pool.getPoolTokensToDepositBasedOnWeth(poolTokenAmount)
        );

        // mint tokens if swapper does not have enough for the swap
        if (poolToken.balanceOf(swapper) < poolTokenAmount) {
            poolToken.mint(
                swapper,
                poolTokenAmount - poolToken.balanceOf(swapper) + 1
            );
        }

        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(
            poolToken,
            weth,
            outputWeth,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // actual
        uint256 endingY = weth.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }

    function deposit(uint256 wethAmount) public {
        uint256 minWeth = pool.getMinimumWethDepositAmount();
        wethAmount = bound(wethAmount, minWeth, type(uint64).max);

        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));

        expectedDeltaY = int256(wethAmount);
        expectedDeltaX = int256(
            pool.getPoolTokensToDepositBasedOnWeth(wethAmount)
        );

        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, wethAmount);
        poolToken.mint(liquidityProvider, uint256(expectedDeltaX));
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);

        pool.deposit(
            wethAmount,
            0,
            uint256(expectedDeltaX),
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // actual
        uint256 endingY = weth.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaY = int256(endingY) - int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);
    }
}
