// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Script, console} from "../../lib/forge-std/src/Script.sol";
import {SmartLTV} from "../../src/core/SmartLTV.sol";
import {BProtocolMorphoAllocator} from "../../src/morpho/BProtocolMorphoAllocator.sol";
import {DeploySmartLTV} from "../core/DeploySmartLTV.s.sol";

import "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import {Market} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";

import {Pythia} from "../../src/core/Pythia.sol";
import {RiskData, Signature} from "../../src/interfaces/RiskData.sol";
import "../../test/TestUtils.sol";

contract ReallocateAllTosDAI is Script {
  uint256 public PRIVATE_KEY;

  Id marketIdSDAI = Id.wrap(0x7a9e4757d1188de259ba5b47f4c08197f821e54109faa5b0502b9dfe2c10b741);
  Id marketIdUSDT = Id.wrap(0xbc6d1789e6ba66e5cd277af475c5ed77fcf8b084347809d9d92e400ebacbdd10);
  Id marketIdIdle = Id.wrap(0x655f87b795c56753741185b9f6fa24c9eb8411bbbbadb44335c9cd4ee0883990);
  IMetaMorpho metaMorpho = IMetaMorpho(0xb6c383fF0257D20e4c9872B6c9F1ce412F4AAC4C);
  IMorpho morpho = IMorpho(0x64c7044050Ba0431252df24fEd4d9635a275CB41);

  MarketParams marketParamSDAI;
  MarketParams marketParamUSDT;
  MarketParams marketParamIdle;
  Pythia public pythia;
  SmartLTV public smartLTV;
  BProtocolMorphoAllocator morphoAllocator = BProtocolMorphoAllocator(0x41Daaf7b733e820FCAbfE211B36fEED6e50D8120);

  function _parseEnv() internal {
    // Default behavior: use Anvil 0 private key
    PRIVATE_KEY = vm.envOr(
      "ETH_PRIVATE_KEY",
      77814517325470205911140941194401928579557062014761831930645393041380819009408
    );
  }

  function prepare() internal {
    marketParamSDAI = morpho.idToMarketParams(marketIdSDAI);
    marketParamUSDT = morpho.idToMarketParams(marketIdUSDT);
    marketParamIdle = morpho.idToMarketParams(marketIdIdle);
    smartLTV = morphoAllocator.SMART_LTV();
    pythia = SmartLTV(smartLTV).PYTHIA();
  }

  function run() public {
    _parseEnv();
    console.log("DATA SIGNING PRIVATE KEY %s", vm.addr(PRIVATE_KEY));
    console.log("MORPHO_ALLOCATOR: %s", address(morphoAllocator));

    prepare();

    (
      MarketAllocation[] memory allocations,
      RiskData[] memory riskDatas,
      Signature[] memory signatures
    ) = generateCheckAndReallocateData();

    vm.startBroadcast(PRIVATE_KEY);
    morphoAllocator.checkAndReallocate(allocations, riskDatas, signatures);
    vm.stopBroadcast();
  }

  function generateRiskDataAndSignature(
    MarketParams memory marketPrm,
    uint8 index,
    RiskData[] memory riskDatas,
    Signature[] memory signatures
  ) public view {
    uint256 liquidity = 100_000_000e18;
    uint256 volatility = 0.001e18;
    (RiskData memory data, uint8 v, bytes32 r, bytes32 s) = TestUtils.signDataValid(
      PRIVATE_KEY,
      marketPrm.collateralToken,
      marketPrm.loanToken,
      pythia.RISKDATA_TYPEHASH(),
      pythia.DOMAIN_SEPARATOR(),
      liquidity,
      volatility
    );

    riskDatas[index] = data;
    signatures[index] = Signature({v: v, r: r, s: s});
  }

  function generateCheckAndReallocateData()
    public
    view
    returns (MarketAllocation[] memory allocations, RiskData[] memory riskDatas, Signature[] memory signatures)
  {
    allocations = new MarketAllocation[](4);
    riskDatas = new RiskData[](4);
    signatures = new Signature[](4);

    allocations[0] = MarketAllocation({marketParams: marketParamUSDT, assets: 0});
    generateRiskDataAndSignature(marketParamUSDT, 0, riskDatas, signatures);
    allocations[1] = MarketAllocation({marketParams: marketParamIdle, assets: 0});
    generateRiskDataAndSignature(marketParamIdle, 1, riskDatas, signatures);
    allocations[2] = MarketAllocation({marketParams: marketParamSDAI, assets: 34700e6});
    generateRiskDataAndSignature(marketParamSDAI, 2, riskDatas, signatures);
    allocations[3] = MarketAllocation({marketParams: marketParamIdle, assets: type(uint256).max});
    generateRiskDataAndSignature(marketParamIdle, 3, riskDatas, signatures);
  }
}
