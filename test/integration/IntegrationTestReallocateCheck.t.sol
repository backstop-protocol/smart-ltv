// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/forge-std/src/Test.sol";
import "../../src/morpho/EmergencyWithdrawal.sol";
import {Market, Position} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IIrm} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IIrm.sol";
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice
/// launch with: forge test --match-contract IntegrationTestReallocateCheck --rpc-url {MAINNET RPC URL} -vvv
contract IntegrationTestReallocateCheck is Test {
  using SharesMathLib for uint256;

  EmergencyWithdrawal public emergencyContract;
  IMetaMorpho public USDC_VAULT;
  IMetaMorpho public ETH_VAULT;
  IMorpho public morpho;

  address public USDC_VAULT_OWNER;
  address public ETH_VAULT_OWNER;

  address allocator = address(0x01010101010101);
  address notAllocator = address(0x02020202020202);

  uint256 public nbBlockToSkip = 7126;

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

  /// @notice Retrieves the current asset supply for a given market ID.
  /// @dev Calculates asset supply based on the total supply shares and positions.
  /// @param marketId The market ID to query.
  /// @return The current asset supply for the specified market.
  function getAssetSupplyForId(Id marketId, address vault) internal view returns (uint256) {
    Market memory m = morpho.market(marketId);
    Position memory p = morpho.position(marketId, vault);

    uint256 currentVaultMarketSupply = SharesMathLib.toAssetsDown(
      p.supplyShares,
      m.totalSupplyAssets,
      m.totalSupplyShares
    );
    return currentVaultMarketSupply;
  }

  function addressToSymbol(address _addr) public view returns (string memory) {
    if (_addr == address(0)) {
      return "idle";
    } else {
      return IERC20Metadata(_addr).symbol();
    }
  }

  function displayMarketStatus(string memory label, IMetaMorpho vault) public {
    uint256 nbMarkets = vault.withdrawQueueLength();
    // console.log("[%s] [%s] markets:", label, vault.name());

    string memory json = "marketStatusJson"; // this is not important

    for (uint256 i = 0; i < nbMarkets; i++) {
      Id marketId = vault.withdrawQueue(i);
      MarketParams memory marketParams = morpho.idToMarketParams(marketId);
      Market memory market = morpho.market(marketId);
      IIrm irm = IIrm(marketParams.irm);

      string memory collateralJson = string.concat("collateral ", addressToSymbol(marketParams.collateralToken)); // this is not important

      uint256 supply = getAssetSupplyForId(marketId, address(vault));
      // console.log(
      //   "collateral %s | ltv %s | supply %s",
      //   addressToSymbol(marketParams.collateralToken),
      //   toPercentageString(marketParams.lltv),
      //   supply
      // );

      vm.serializeString(collateralJson, "collateral", addressToSymbol(marketParams.collateralToken));
      vm.serializeString(collateralJson, "lltv", toPercentageString(marketParams.lltv));
      vm.serializeUint(collateralJson, "totalBorrowAssets", market.totalBorrowAssets);
      string memory cJson = vm.serializeUint(collateralJson, "totalSupplyAssets", market.totalSupplyAssets);

      if (address(irm) != address(0)) {
        uint256 borrowRate = irm.borrowRateView(marketParams, market);
        // console.log(
        //   "{\"block\": %s, \"collateral\": \"%s\", \"borrowRate\": %s }",
        //   block.number,
        //   addressToSymbol(marketParams.collateralToken),
        //   borrowRate
        // );

        cJson = vm.serializeUint(collateralJson, "borrowRate", borrowRate);

        // console.log(
        //   "{\"block\": %s, \"totalBorrowAssets\": \"%s\", \"totalSupplyAssets\": %s }",
        //   block.number,
        //   market.totalBorrowAssets,
        //   market.totalSupplyAssets
        // );
      }

      string memory finalJson = vm.serializeString(json, addressToSymbol(marketParams.collateralToken), cJson);
    }

    
    string memory f = vm.serializeUint(json, "block", uint256(block.number));
    console.log(f);
  }

  function setUp() public {
    emergencyContract = new EmergencyWithdrawal();
    USDC_VAULT = IMetaMorpho(emergencyContract.USDC_VAULT());
    ETH_VAULT = IMetaMorpho(emergencyContract.ETH_VAULT());
    morpho = ETH_VAULT.MORPHO();

    USDC_VAULT_OWNER = USDC_VAULT.owner();
    ETH_VAULT_OWNER = ETH_VAULT.owner();

    vm.startPrank(USDC_VAULT_OWNER);
    USDC_VAULT.setIsAllocator(allocator, true);
    USDC_VAULT.setIsAllocator(address(emergencyContract), true);
    vm.stopPrank();

    vm.startPrank(ETH_VAULT_OWNER);
    ETH_VAULT.setIsAllocator(allocator, true);
    ETH_VAULT.setIsAllocator(address(emergencyContract), true);
    vm.stopPrank();
  }

  function testEmergencyWithdrawETH() public {
    // string memory obj1 = "some key";
    // string memory finalJson = vm.serializeBool(obj1, "boolean", true);
    // console.log(finalJson);

    // finalJson = vm.serializeUint(obj1, "number", uint256(342));
    // console.log(finalJson);

    // string memory obj2 = "some other key";
    // string memory output = vm.serializeString(obj2, "title", "finally json serialization");

    // finalJson = vm.serializeString(obj1, "object", output);
    // console.log(finalJson);
    displayMarketStatus("BEFORE", ETH_VAULT);
    vm.prank(allocator);
    emergencyContract.withdrawETH();
    // // displayMarketStatus("AFTER", ETH_VAULT);
    // // console.log("block %s, timestamp %s", block.number, block.timestamp);
    vm.roll(block.number + (nbBlockToSkip * 7));
    vm.warp(block.timestamp + (nbBlockToSkip * 7 * 12));
    // // console.log("block %s, timestamp %s", block.number, block.timestamp);
    displayMarketStatus("AFTER", ETH_VAULT);
  }
}
