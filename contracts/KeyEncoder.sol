// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract KeyEncoder {
    enum VolatilityMode {
        Standard,
        DailyMovement
    }

    enum LiquiditySource {
        All,
        UniV2,
        UniV3,
        Curve
    }

    function encodeVolatilityKey(
        address /* collateralAsset */,
        address debtAsset,
        VolatilityMode mode,
        uint period
    )
        external
        pure
        returns(bytes32) {

        return keccak256(abi.encode("volatility", debtAsset, mode, period));
    }

    function encodeLiquidityKey(
        address /* collateralAsset */,
        address debtAsset,        
        LiquiditySource source,
        uint slippage,
        uint period
    )
        external
        pure
        returns(bytes32) {

        return keccak256(abi.encode("liquidity", debtAsset, source, slippage, period));
    }
}