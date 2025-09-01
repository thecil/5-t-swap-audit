## Findings

## HIGH

### [H-1] `TSwapPool::deposit` function `deadline` parameter not being use to check the transaction deadline.

**Description**:  The deposit function in the TSwapPool contract accepts a deadline parameter but does not utilize it to verify whether the transaction has been submitted before the deadline. This omission allows users to submit transactions after the intended time, potentially causing disruptions to the functionality of the system.

**Impact**: High.

A user who expects a deposit to fail because it exceeds the deadline will be able to proceed with the transaction, leading to severe disruption of the protocol.

**Impact**: High.

This condition is always true unless explicitly checked and enforced within the function.

**Proof of Concept**: (Proof of Code)

This is the actual code for the function:

<details> 
<summary>view code</summary>

```solidity
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
    )
        external
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint)
    {
        if (wethToDeposit < MINIMUM_WETH_LIQUIDITY) {
            revert TSwapPool__WethDepositAmountTooLow(
                MINIMUM_WETH_LIQUIDITY,
                wethToDeposit
            );
        }
        if (totalLiquidityTokenSupply() > 0) {
            uint256 wethReserves = i_wethToken.balanceOf(address(this));
            uint256 poolTokenReserves = i_poolToken.balanceOf(address(this));
            // Our invariant says weth, poolTokens, and liquidity tokens must always have the same ratio after the
            // initial deposit
            // poolTokens / constant(k) = weth
            // weth / constant(k) = liquidityTokens
            // aka...
            // weth / poolTokens = constant(k)
            // To make sure this holds, we can make sure the new balance will match the old balance
            // (wethReserves + wethToDeposit) / (poolTokenReserves + poolTokensToDeposit) = constant(k)
            // (wethReserves + wethToDeposit) / (poolTokenReserves + poolTokensToDeposit) =
            // (wethReserves / poolTokenReserves)
            //
            // So we can do some elementary math now to figure out poolTokensToDeposit...
            // (wethReserves + wethToDeposit) = (poolTokenReserves + poolTokensToDeposit) * (wethReserves /
            // poolTokenReserves)
            // wethReserves + wethToDeposit  = poolTokenReserves * (wethReserves / poolTokenReserves) +
            // poolTokensToDeposit * (wethReserves / poolTokenReserves)
            // wethReserves + wethToDeposit = wethReserves + poolTokensToDeposit * (wethReserves / poolTokenReserves)
            // wethToDeposit / (wethReserves / poolTokenReserves) = poolTokensToDeposit
            // (wethToDeposit * poolTokenReserves) / wethReserves = poolTokensToDeposit
            uint256 poolTokensToDeposit = getPoolTokensToDepositBasedOnWeth(
                wethToDeposit
            );
            if (maximumPoolTokensToDeposit < poolTokensToDeposit) {
                revert TSwapPool__MaxPoolTokenDepositTooHigh(
                    maximumPoolTokensToDeposit,
                    poolTokensToDeposit
                );
            }

            // We do the same thing for liquidity tokens. Similar math.
            liquidityTokensToMint =
                (wethToDeposit * totalLiquidityTokenSupply()) /
                wethReserves;
            if (liquidityTokensToMint < minimumLiquidityTokensToMint) {
                revert TSwapPool__MinLiquidityTokensToMintTooLow(
                    minimumLiquidityTokensToMint,
                    liquidityTokensToMint
                );
            }
            _addLiquidityMintAndTransfer(
                wethToDeposit,
                poolTokensToDeposit,
                liquidityTokensToMint
            );
        } else {
            // This will be the "initial" funding of the protocol. We are starting from blank here!
            // We just have them send the tokens in, and we mint liquidity tokens based on the weth
            _addLiquidityMintAndTransfer(
                wethToDeposit,
                maximumPoolTokensToDeposit,
                wethToDeposit
            );
            liquidityTokensToMint = wethToDeposit;
        }
    }
```
</details>

**Recommended Mitigation**: Add the `revertIfDeadlinePassed` modifier to ensure that the transaction has been submitted before the specified deadline.

```diff
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
    )
        external
+       revertIfDeadlinePassed(deadline)
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint)
```

## MEDIUM
## LOW
## INFORMATIONAL

### [I-1] - At `PoolFactory::PoolFactory__PoolDoesNotExist` error is not used and should be removed.

**Description**: The error `PoolFactory__PoolDoesNotExist` is not used in the codebase. It should be removed.

**Impact**: Low.

**Recommended Mitigation**: Remove the `PoolFactory__PoolDoesNotExist` error from the codebase.

```diff
- error PoolFactory__PoolDoesNotExist(address tokenAddress);
```

### [I-2] - `TSwapPool::Swap` event is missing `indexed` fields.

**Description**: 

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it’s not necessarily best to index the maximum allowed per event (threefields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

The `TSwapPool::Swap` event should have at least 3 indexed parameters.

**Impact**: low.

**Proof of Concept**: (Proof of Code)

This is the actual code for the `Swap` event:

```solidity
    event Swap(
        address indexed swapper,
        IERC20 tokenIn,
        uint256 amountTokenIn,
        IERC20 tokenOut,
        uint256 amountTokenOut
    );
```

**Recommended Mitigation**: Change the event parameters type to the following:

```diff
event Swap(
    address indexed swapper,
-   IERC20 tokenIn,
+   address indexed tokenIn, 
    uint256 amountTokenIn,
-   IERC20 tokenOut,
+   address indexed tokenOut,
    uint256 amountTokenOut
);
```

### [I-3] - `TSwapPool::constructor` is lacking zero address checks.

**Description**: At `TSwapPool::constructor` requires 2 inputed addresses `poolToken` & `wethToken` to initialize the contract with `i_wethToken` & `i_poolToken` values, but there is no zero address checks in the constructor, this might lead to an incorrect initialization of the contract.

**Impact**: HIGH.

**Proof of Concept**: (Proof of Code)

The following code is the actual codebase of the constructor for `TSwapPool`

```solidity
    constructor(
        address poolToken,
        address wethToken,
        string memory liquidityTokenName,
        string memory liquidityTokenSymbol
    ) ERC20(liquidityTokenName, liquidityTokenSymbol) {
        i_wethToken = IERC20(wethToken);
        i_poolToken = IERC20(poolToken);
    }
```

**Recommended Mitigation**: Add a check for each of the inputed addresses.

```diff
+   error TSwapPool__ZeroAddressNotAllowed();

    constructor(
        address poolToken,
        address wethToken,
        string memory liquidityTokenName,
        string memory liquidityTokenSymbol
    ) ERC20(liquidityTokenName, liquidityTokenSymbol) {
+       if(poolToken == address(0) || wethToken == address(0)){
+           revert TSwapPool__ZeroAddressNotAllowed();
+       }
        i_wethToken = IERC20(wethToken);
        i_poolToken = IERC20(poolToken);
    }
```

### [I-4] - `PoolFactory::createPool` at `liquidityTokenName` weird erc20 might not have the `.name()` function, requires a check.

**Description**: 

**Impact**:

**Proof of Concept**: (Proof of Code)


**Recommended Mitigation**: 

### [I-5] - `PoolFactory::createPool` at `liquidityTokenSymbol` should be .symbol() instead of .name()

**Description**: 

**Impact**:

**Proof of Concept**: (Proof of Code)

**Recommended Mitigation**: Change the following line:

```diff
    function createPool(address tokenAddress) external returns (address) {
        if (s_pools[tokenAddress] != address(0)) {
            revert PoolFactory__PoolAlreadyExists(tokenAddress);
        }
        string memory liquidityTokenName = string.concat("T-Swap ", IERC20(tokenAddress).name());
-       string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
+       string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());
        TSwapPool tPool = new TSwapPool(tokenAddress, i_wethToken, liquidityTokenName, liquidityTokenSymbol);
        s_pools[tokenAddress] = address(tPool);
        s_tokens[address(tPool)] = tokenAddress;
        emit PoolCreated(tokenAddress, address(tPool));
        return address(tPool);
    }
```


### [I-6] - 

**Description**:

**Impact**:

**Proof of Concept**: (Proof of Code)

**Recommended Mitigation**: 

## GAS

### [I-2] - 

**Description**:

**Impact**:

**Proof of Concept**: (Proof of Code)

**Recommended Mitigation**: 