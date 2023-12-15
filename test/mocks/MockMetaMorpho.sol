// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import "../../lib/forge-std/src/Test.sol";

contract MockMetaMorpho is IMetaMorpho {
  IMorpho public MORPHO;
  mapping(Id => MarketConfig) public configs;

  constructor(IMorpho _morpho) {
    MORPHO = _morpho;
  }

  function isAllocator(address target) external view returns (bool) {
    return true;
  }

  function owner() external pure returns (address) {
    return address(1);
  }

  function setConfig(Id id, MarketConfig memory marketConfig) external {
    configs[id] = marketConfig;
  }

  function config(Id id) external view override returns (MarketConfig memory) {
    return configs[id];
  }

  function curator() external view override returns (address) {
    return address(0); // Placeholder value
  }

  function guardian() external view override returns (address) {
    return address(0); // Placeholder value
  }

  function fee() external view override returns (uint96) {
    return uint96(0); // Placeholder value
  }

  function feeRecipient() external view override returns (address) {
    return address(0); // Placeholder value
  }

  function skimRecipient() external view override returns (address) {
    return address(0); // Placeholder value
  }

  function timelock() external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function supplyQueue(uint256) external view override returns (Id) {
    return Id(0); // Placeholder value
  }

  function supplyQueueLength() external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function withdrawQueue(uint256) external view override returns (Id) {
    return Id(0); // Placeholder value
  }

  function withdrawQueueLength() external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function lastTotalAssets() external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  // Stub implementations for the rest of the methods in the IMetaMorphoBase interface
  function submitTimelock(uint256) external override {
    // Placeholder body
  }

  function acceptTimelock() external override {
    // Placeholder body
  }

  function revokePendingTimelock() external override {
    // Placeholder body
  }

  function submitCap(MarketParams memory, uint256) external override {
    // Placeholder body
  }

  function acceptCap(Id) external override {
    // Placeholder body
  }

  function revokePendingCap(Id) external override {
    // Placeholder body
  }

  function submitMarketRemoval(Id) external override {
    // Placeholder body
  }

  function revokePendingMarketRemoval(Id) external override {
    // Placeholder body
  }

  function submitGuardian(address) external override {
    // Placeholder body
  }

  function acceptGuardian() external override {
    // Placeholder body
  }

  function revokePendingGuardian() external override {
    // Placeholder body
  }

  function skim(address) external override {
    // Placeholder body
  }

  function setIsAllocator(address, bool) external override {
    // Placeholder body
  }

  function setCurator(address) external override {
    // Placeholder body
  }

  function setFee(uint256) external override {
    // Placeholder body
  }

  function setFeeRecipient(address) external override {
    // Placeholder body
  }

  function setSkimRecipient(address) external override {
    // Placeholder body
  }

  function setSupplyQueue(Id[] calldata) external override {
    // Placeholder body
  }

  function updateWithdrawQueue(uint256[] calldata) external override {
    // Placeholder body
  }

  function reallocate(MarketAllocation[] calldata) external override {
    // Placeholder body
  }

  // Implementations of IERC4626 methods
  function totalAssets() external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function convertToShares(uint256) external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function convertToAssets(uint256) external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function maxDeposit(address) external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function previewDeposit(uint256) external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function deposit(uint256, address) external override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function maxWithdraw(address) external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function previewWithdraw(uint256) external view override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function withdraw(uint256, address, address) external override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  // Implementations of IERC20Permit methods
  function permit(address, address, uint256, uint256, uint8, bytes32, bytes32) external override {
    // Placeholder body
  }

  function transferOwnership(address) external override {
    // Placeholder body
  }

  function renounceOwnership() external override {
    // Placeholder body
  }

  function acceptOwnership() external override {
    // Placeholder body
  }

  function pendingOwner() external view override returns (address) {
    return address(0); // Placeholder value
  }

  // Implementations of IMulticall methods
  function multicall(bytes[] calldata) external override returns (bytes[] memory) {
    return new bytes[](0); // Placeholder value
  }

  function pendingGuardian() external view override returns (PendingAddress memory) {
    return PendingAddress(address(0), 0); // Placeholder value
  }

  function pendingCap(Id) external view override returns (PendingUint192 memory) {
    return PendingUint192(0, 0); // Placeholder value
  }

  function pendingTimelock() external view override returns (PendingUint192 memory) {
    return PendingUint192(0, 0); // Placeholder value
  }

  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return bytes32(0); // Placeholder value
  }

  function allowance(address, address) external view returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function approve(address, uint256) external returns (bool) {
    return true; // Placeholder value
  }

  function asset() external view returns (address assetTokenAddress) {
    return address(0); // Placeholder value
  }

  function balanceOf(address) external view returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function decimals() external view returns (uint8) {
    return uint8(0); // Placeholder value
  }

  function maxMint(address) external view returns (uint256 maxShares) {
    return uint256(0); // Placeholder value
  }

  function maxRedeem(address) external view returns (uint256 maxShares) {
    return uint256(0); // Placeholder value
  }

  function mint(uint256, address) external returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function name() external view returns (string memory) {
    return ""; // Placeholder value
  }

  function nonces(address) external view returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function previewMint(uint256) external view returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function previewRedeem(uint256) external view returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function redeem(uint256, address, address) external returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function symbol() external view returns (string memory) {
    return ""; // Placeholder value
  }

  function totalSupply() external view returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function transfer(address, uint256) external returns (bool) {
    return true; // Placeholder value
  }

  function transferFrom(address, address, uint256) external returns (bool) {
    return true; // Placeholder value
  }
}
