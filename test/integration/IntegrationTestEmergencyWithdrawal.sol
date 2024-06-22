// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/forge-std/src/Test.sol";
import "../../src/morpho/EmergencyWithdrawal.sol";
import {Market, Position} from "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice
/// launch with: forge test --match-contract IntegrationTestEmergencyWithdrawal --rpc-url {MAINNET RPC URL} -vvv
contract IntegrationTestEmergencyWithdrawal is Test {
  using SharesMathLib for uint256;

  EmergencyWithdrawal public emergencyContract;
  IMetaMorpho public USDC_VAULT;
  IMetaMorpho public ETH_VAULT;
  IMorpho public morpho;

  address public USDC_VAULT_OWNER;
  address public ETH_VAULT_OWNER;

  address allocator = address(0x01010101010101);
  address notAllocator = address(0x02020202020202);

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

  function displayMarketStatus(string memory label, IMetaMorpho vault) public view {
    uint256 nbMarkets = vault.withdrawQueueLength();
    console.log("[%s] [%s] markets:", label, vault.name());

    for (uint256 i = 0; i < nbMarkets; i++) {
      Id marketId = vault.withdrawQueue(i);
      MarketParams memory marketParams = morpho.idToMarketParams(marketId);

      uint256 supply = getAssetSupplyForId(marketId, address(vault));
      console.log(
        "collateral %s | ltv %s | supply %s",
        addressToSymbol(marketParams.collateralToken),
        toPercentageString(marketParams.lltv),
        supply
      );
    }
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

  function testInitialize() public {
    assertEq(address(USDC_VAULT), address(emergencyContract.USDC_VAULT()));
    assertEq(USDC_VAULT.isAllocator(allocator), true);
    assertEq(ETH_VAULT.isAllocator(allocator), true);
  }

  function testEmergencyWithdrawETHDoesNotWorkIfNotAllocator() public {
    vm.prank(notAllocator);
    vm.expectRevert("EmergencyWithdrawal: msg.sender is not vault allocator");
    emergencyContract.withdrawETH();
  }

  function testEmergencyWithdrawUSDCDoesNotWorkIfNotAllocator() public {
    vm.prank(notAllocator);
    vm.expectRevert("EmergencyWithdrawal: msg.sender is not vault allocator");
    emergencyContract.withdrawUSDC();
  }

  function testEmergencyWithdrawETH() public {
    displayMarketStatus("BEFORE", ETH_VAULT);
    vm.prank(allocator);
    emergencyContract.withdrawETH();
    displayMarketStatus("AFTER", ETH_VAULT);
  }

  function testEmergencyWithdrawUSDC() public {
    displayMarketStatus("BEFORE", USDC_VAULT);
    vm.prank(allocator);
    emergencyContract.withdrawUSDC();
    displayMarketStatus("AFTER", USDC_VAULT);
  }

  function testEmergencyWithdrawETHSupplyQueue() public {
    vm.prank(allocator);
    emergencyContract.withdrawETH();
    assertEq(ETH_VAULT.supplyQueueLength(), 0);
  }

  function testEmergencyWithdrawUSDCSupplyQueue() public {
    vm.prank(allocator);
    emergencyContract.withdrawUSDC();
    assertEq(USDC_VAULT.supplyQueueLength(), 0);
  }
}
