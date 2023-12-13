// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../src/external/Morpho.sol";
import "../src/interfaces/RiskData.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "../lib/forge-std/src/Test.sol";

library TestUtils {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  function signDataValid(
    uint256 trustedRelayerPrivateKey,
    address collateralAddress,
    address debtAddress,
    bytes32 riskdataTypehash,
    bytes32 domainSeparator,
    uint256 liquidity,
    uint256 volatility
  ) internal view returns (RiskData memory data, uint8 v, bytes32 r, bytes32 s) {
    data = RiskData({
      collateralAsset: collateralAddress,
      debtAsset: debtAddress,
      liquidity: liquidity,
      volatility: volatility,
      lastUpdate: block.timestamp - 3600, // 1 hour old data
      chainId: block.chainid
    });

    // sign risk data
    bytes32 structHash = keccak256(
      abi.encode(
        riskdataTypehash,
        data.collateralAsset,
        data.debtAsset,
        data.liquidity,
        data.volatility,
        data.lastUpdate,
        data.chainId
      )
    );

    bytes32 digest = MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    (v, r, s) = vm.sign(trustedRelayerPrivateKey, digest);
  }
}
