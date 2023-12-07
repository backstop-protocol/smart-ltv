// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {RiskData, Signature} from "../interfaces/RiskData.sol";
import {SmartLTV} from "../core/SmartLTV.sol";
import {IMetaMorpho, MarketAllocation, Id, MarketParams, IMorpho} from "../external/Morpho.sol";
import {RiskyMath} from "../lib/RiskyMath.sol";
import {MorphoLib} from "../external/Morpho.sol";
import {ErrorLib} from "../lib/ErrorLib.sol";

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
  SmartLTV immutable SMART_LTV;
  address immutable TRUSTED_RELAYER;
  address immutable METAMORPHO_VAULT;
  uint256 immutable MIN_CLF = 3;

  constructor(SmartLTV smartLTV, address relayer, address morphoVault) {
    SMART_LTV = smartLTV;
    TRUSTED_RELAYER = relayer;
    METAMORPHO_VAULT = morphoVault;
  }

  function checkAndReallocate(
    MarketAllocation[] calldata allocations,
    RiskData[] calldata riskDatas,
    Signature[] calldata signatures
  ) external {
    if (allocations.length != riskDatas.length) {
      revert ErrorLib.INVALID_RISK_DATA_COUNT(
        allocations.length,
        riskDatas.length
      );
    }

    if (riskDatas.length != signatures.length) {
      revert ErrorLib.INVALID_SIGNATURE_COUNT(
        riskDatas.length,
        signatures.length
      );
    }

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
  ) private view {
    // get market config from the vault
    Id marketId = MorphoLib.id(allocation.marketParams);
    (uint184 cap, , ) = IMetaMorpho(METAMORPHO_VAULT).config(marketId);

    uint256 d = cap; // supplyCap
    uint256 beta = 15487; // TODO REAL liquidation bonus

    uint recommendedLtv = SMART_LTV.ltv(
      riskData.collateralAsset,
      riskData.debtAsset,
      d,
      beta,
      MIN_CLF,
      riskData,
      signature.v,
      signature.r,
      signature.s
    );

    // check if the current ltv is lower or equal to the recommended ltv
    if (allocation.marketParams.lltv > recommendedLtv) {
      revert ErrorLib.LTV_TOO_HIGH(
        allocation.marketParams.lltv,
        recommendedLtv
      );
    }
  }
}
