// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../src/interfaces/RiskData.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "../lib/forge-std/src/Test.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Market, Position} from "../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IMorpho} from "../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoLib} from "../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "../lib/metamorpho/lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {MathLib, WAD} from "../lib/metamorpho/lib/morpho-blue/src/libraries/MathLib.sol";
import {SharesMathLib} from "../lib/metamorpho/lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {MarketParamsLib, MarketParams} from "../lib/metamorpho/lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {IMetaMorpho, IMetaMorphoBase, MarketAllocation, Id, MarketConfig} from "../lib/metamorpho/src/interfaces/IMetaMorpho.sol";

library TestUtils {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  // fake function so that does not show up in the coverage report
  function test() public {}

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

  function toPercentageString(uint256 value) public pure returns (string memory) {
    require(value <= 1e20, "Value too large");

    uint256 percentageValue = (value * 100) / 1e16; // Convert to percentage
    uint256 integerPart = percentageValue / 100;
    uint256 fractionalPart = percentageValue % 100;

    return
      string(
        abi.encodePacked(
          uintToString(integerPart),
          ".",
          fractionalPart < 10 ? "0" : "", // Add leading zero for single digit fractional part
          uintToString(fractionalPart),
          "%"
        )
      );
  }

  function uintToString(uint256 value) internal pure returns (string memory) {
    // This function converts an unsigned integer to a string.
    if (value == 0) {
      return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + (value % 10)));
      value /= 10;
    }
    return string(buffer);
  }

  function addressToSymbol(address _addr) public view returns (string memory) {
    if (_addr == address(0)) {
      return "IDLE";
    } else {
      return IERC20Metadata(_addr).symbol();
    }
  }

  /// @notice Retrieves the current asset supply for a given market ID.
  /// @dev Calculates asset supply based on the total supply shares and positions.
  /// @param marketId The market ID to query.
  /// @return The current asset supply for the specified market.
  function getAssetSupplyForId(Id marketId, address vault, IMorpho morpho) public view returns (uint256) {
    Market memory m = morpho.market(marketId);
    Position memory p = morpho.position(marketId, vault);

    uint256 currentVaultMarketSupply = SharesMathLib.toAssetsDown(
      p.supplyShares,
      m.totalSupplyAssets,
      m.totalSupplyShares
    );
    return currentVaultMarketSupply;
  }

  function displayMarketStatus(string memory label, IMetaMorpho vault, IMorpho morpho) public view {
    uint256 nbMarkets = vault.withdrawQueueLength();
    console.log("[%s] [%s] markets:", label, vault.name());

    for (uint256 i = 0; i < nbMarkets; i++) {
      Id marketId = vault.withdrawQueue(i);
      Market memory m = morpho.market(marketId);

      MarketParams memory marketParams = morpho.idToMarketParams(marketId);

      uint256 supply = getAssetSupplyForId(marketId, address(vault), morpho);
      string memory logToDisplay = string.concat(addressToSymbol(marketParams.collateralToken), " market");
      logToDisplay = string.concat(logToDisplay, " | ltv ");
      logToDisplay = string.concat(logToDisplay, toPercentageString(marketParams.lltv));
      logToDisplay = string.concat(logToDisplay, " | vault supply ");
      logToDisplay = string.concat(logToDisplay, uintToString(supply));
      logToDisplay = string.concat(logToDisplay, " | total supply ");
      logToDisplay = string.concat(logToDisplay, uintToString(m.totalSupplyAssets));
      logToDisplay = string.concat(logToDisplay, " | total borrow ");
      logToDisplay = string.concat(logToDisplay, uintToString(m.totalBorrowAssets));
      logToDisplay = string.concat(logToDisplay, " | utilization ");
      uint256 utilization = m.totalSupplyAssets == 0
        ? 0
        : (uint256(m.totalBorrowAssets) * 1e18) / uint256(m.totalSupplyAssets);
      logToDisplay = string.concat(logToDisplay, toPercentageString(utilization));

      console.log(logToDisplay);
    }
  }
}
