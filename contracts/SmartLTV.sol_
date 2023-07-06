// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "./Pythia.sol";
import "./KeyEncoder.sol";
import "./RiskyMath.sol";

contract SmartLTV is RiskyMath {
    Pythia immutable pythia;
    KeyEncoder immutable keyEncoder;
    address immutable trustedRelayer;

    uint constant CLF = 7e15;
    uint constant TIME_PERIOD = 1 days * 365;
    KeyEncoder.VolatilityMode VOLATILITY_MODE = KeyEncoder.VolatilityMode.Standard;
    KeyEncoder.LiquiditySource LIQUIDITY_SOURCE = KeyEncoder.LiquiditySource.All;

    constructor(Pythia _pythia, KeyEncoder _keyEncoder, address _trustedRelayer) {
        pythia = _pythia;
        keyEncoder = _keyEncoder;
        trustedRelayer = _trustedRelayer;
    }

    function getDebtCeling(address debtAsset) public pure returns(uint) {
        // TODO - read from actual lending platform
        debtAsset;
        return 700_000 * 1e18;
    }

    function getLiquidationIncentive(address collateralAsset) public pure returns(uint) {
        // TODO - read from actual lending platform
        collateralAsset;
        return 5e16;
    }

    function getVolatility(address collateralAsset, address debtAsset) public view returns(uint value) {
        bytes32 key = keyEncoder.encodeVolatilityKey(collateralAsset, debtAsset, VOLATILITY_MODE, TIME_PERIOD);

        Pythia.Data memory data = pythia.get(trustedRelayer, collateralAsset, key);
        require(data.lastUpdate >= block.timestamp - 1 days, "stale data");

        value = data.value;
    }

    function getLiquidity(address collateralAsset, address debtAsset, uint liquiditationIncentive) public view returns(uint value) {
        bytes32 key = keyEncoder.encodeLiquidityKey(collateralAsset, debtAsset, LIQUIDITY_SOURCE, liquiditationIncentive, TIME_PERIOD);

        Pythia.Data memory data = pythia.get(trustedRelayer, collateralAsset, key);
        require(data.lastUpdate >= block.timestamp - 1 days, "stale data");

        value = data.value;        
    }

    function ltv(address collateralAsset, address debtAsset) public view returns(uint) {
        uint sigma = getVolatility(collateralAsset, debtAsset);
        uint beta = getLiquidationIncentive(collateralAsset);
        uint l = getLiquidity(collateralAsset, debtAsset, beta);
        uint d = getDebtCeling(debtAsset);

        // LTV  = e ^ (-c * sigma / sqrt(l/d)) - beta
        uint cTimesSigma = CLF * sigma / 1e18;
        uint sqrtValue = sqrt(1e18 * l / d) * 1e9;
        uint mantissa = (1 << 59) * cTimesSigma / sqrtValue;

        uint expResult = generalExp(mantissa, 59);

        return (1e18 * (1 << 59)) / expResult - beta;
    }    
}

