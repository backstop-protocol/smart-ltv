// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {ISPythia, Signature, RiskData} from "./interfaces/ISPythia.sol";
import {IMetaMorpho, MarketAllocation, Id, MarketParams} from "./interfaces/IMetaMorpho.sol";
import {RiskyMath} from "./lib/RiskyMath.sol";
import {MorphoLib} from "./lib/MorphoLib.sol";

/*  
USDC/sDAI
marketid 0x7a9e4757d1188de259ba5b47f4c08197f821e54109faa5b0502b9dfe2c10b741
loanToken   address :  0x62bD2A599664D421132d7C54AB4DbE3233f4f0Ae
  collateralToken   address :  0xD8134205b0328F5676aaeFb3B2a0DC15f4029d8C
  oracle   address :  0xc1466Cc7e9ace925fA54398f99D2277a571A7a0a
  irm   address :  0x9ee101eB4941d8D7A665fe71449360CEF3C8Bb87
  lltv   uint256 :  900000000000000000
  
  
USDC/USDT
marketid: 0xbc6d1789e6ba66e5cd277af475c5ed77fcf8b084347809d9d92e400ebacbdd10
  loanToken   address :  0x62bD2A599664D421132d7C54AB4DbE3233f4f0Ae
  collateralToken   address :  0x576e379FA7B899b4De1E251e935B31543Df3e954
  oracle   address :  0x095613a8C57a294E43E2bb5B62D628D8C8B00dAA
  irm   address :  0x9ee101eB4941d8D7A665fe71449360CEF3C8Bb87
  lltv   uint256 :  900000000000000000
*/

contract BProtocolMorphoAllocator {
  using MorphoLib for MarketParams;

  ISPythia immutable SPYTHIA;
  address immutable TRUSTED_RELAYER;
  address immutable METAMORPHO_VAULT;
  uint256 immutable MIN_CLF = 3;

  error INVALID_NUMBER_OF_RISK_DATA(uint256 a);

  constructor(ISPythia spythia, address relayer, address morphoVault) {
    SPYTHIA = spythia;
    TRUSTED_RELAYER = relayer;
    METAMORPHO_VAULT = morphoVault;
  }

  function checkAndReallocate(
    MarketAllocation[] calldata allocations,
    RiskData[] calldata riskDatas,
    Signature[] calldata signatures
  ) external {
    if(allocations.length != riskDatas.length) {
        revert INVALID_NUMBER_OF_RISK_DATA(250);
    }

    require(
      riskDatas.length == signatures.length,
      "Invalid number of signatures"
    );

    for (uint256 i = 0; i < allocations.length; i++) {
      _checkAllocationRisk(allocations[i], riskDatas[i], signatures[i]);
    }

    // call reallocate
    IMetaMorpho(METAMORPHO_VAULT).reallocate(allocations);
  }

  function _checkAllocationRisk(
    MarketAllocation memory allocation,
    RiskData memory riskData,
    Signature memory signature
  ) private {
    require(
      allocation.marketParams.collateralToken == riskData.collateralAsset,
      "Allocation collateral token != riskData.collateralAsset"
    );
    require(
      allocation.marketParams.loanToken == riskData.debtAsset,
      "allocation.loanToken != riskData.debtAsset"
    );

    // Verify if the signature comes from the trusted relayer
    address signer = SPYTHIA.getSigner(
      riskData,
      signature.v,
      signature.r,
      signature.s
    );
    require(signer == TRUSTED_RELAYER, "invalid signer");

    // timeout
    require(riskData.lastUpdate + 1 days >= block.timestamp, "timeout");

    // chain id
    require(riskData.chainId == block.chainid, "invalid chainId");

    // get market config from the vault
    Id marketId = allocation.marketParams.id();
    (uint184 cap, , ) = IMetaMorpho(METAMORPHO_VAULT).config(marketId);

    uint256 sigma = riskData.volatility;
    uint256 l = riskData.liquidity;
    uint256 d = cap; // supplyCap
    uint256 beta = 15487; // liquidation bonus

    // LTV  = e ^ (-c * sigma / sqrt(l/d)) - beta
    uint256 cTimesSigma = (MIN_CLF * sigma) / 1e18;
    uint256 sqrtValue = RiskyMath.sqrt((1e18 * l) / d) * 1e9;
    uint256 mantissa = ((1 << 59) * cTimesSigma) / sqrtValue;

    uint256 expResult = RiskyMath.generalExp(mantissa, 59);

    uint256 recommendedLtv = (1e18 * (1 << 59)) / expResult - beta;

    // check if the current ltv is lower or equal to the recommended ltv
    require(
      recommendedLtv >= allocation.marketParams.lltv,
      "recommended ltv is lower than current lltv"
    );
  }
}
