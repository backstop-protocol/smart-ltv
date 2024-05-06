// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/metamorpho/src/interfaces/IMetaMorpho.sol";
import "../../lib/forge-std/src/Test.sol";

contract MockMetaMorpho is IMetaMorpho {
  IMorpho public MORPHO;
  mapping(Id => MarketConfig) public configs;
  Id[] public marketIds;

  constructor(IMorpho _morpho) {
    MORPHO = _morpho;
  }

  function isAllocator(address /*target*/) external pure returns (bool) {
    return true;
  }

  function owner() external pure returns (address) {
    return address(1);
  }

  function setMarkets(Id[] memory _marketIds) external {
    marketIds = _marketIds;
  }

  function setConfig(Id id, MarketConfig memory marketConfig) external {
    configs[id] = marketConfig;
  }

  function config(Id id) external view override returns (MarketConfig memory) {
    return configs[id];
  }

  function withdrawQueue(uint256 _index) external view override returns (Id) {
    return marketIds[_index];
  }

  function withdrawQueueLength() external view override returns (uint256) {
    return marketIds.length;
  }

  function curator() external pure override returns (address) {
    return address(0); // Placeholder value
  }

  function guardian() external pure override returns (address) {
    return address(0); // Placeholder value
  }

  function fee() external pure override returns (uint96) {
    return uint96(0); // Placeholder value
  }

  function feeRecipient() external pure override returns (address) {
    return address(0); // Placeholder value
  }

  function skimRecipient() external pure override returns (address) {
    return address(0); // Placeholder value
  }

  function timelock() external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function supplyQueue(uint256) external pure override returns (Id) {
    return Id.wrap(bytes32(0)); // Placeholder value
  }

  function supplyQueueLength() external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function lastTotalAssets() external pure override returns (uint256) {
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
  function totalAssets() external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function convertToShares(uint256) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function convertToAssets(uint256) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function maxDeposit(address) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function previewDeposit(uint256) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function deposit(uint256, address) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function maxWithdraw(address) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function previewWithdraw(uint256) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function withdraw(uint256, address, address) external pure override returns (uint256) {
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

  function pendingOwner() external pure override returns (address) {
    return address(0); // Placeholder value
  }

  // Implementations of IMulticall methods
  function multicall(bytes[] calldata) external pure override returns (bytes[] memory) {
    return new bytes[](0); // Placeholder value
  }

  function pendingGuardian() external pure override returns (PendingAddress memory) {
    return PendingAddress(address(0), 0); // Placeholder value
  }

  function pendingCap(Id) external pure override returns (PendingUint192 memory) {
    return PendingUint192(0, 0); // Placeholder value
  }

  function pendingTimelock() external pure override returns (PendingUint192 memory) {
    return PendingUint192(0, 0); // Placeholder value
  }

  function DOMAIN_SEPARATOR() external pure returns (bytes32) {
    return bytes32(0); // Placeholder value
  }

  function allowance(address, address) external pure returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function approve(address, uint256) external pure returns (bool) {
    return true; // Placeholder value
  }

  function asset() external pure returns (address assetTokenAddress) {
    return address(0); // Placeholder value
  }

  function balanceOf(address) external pure returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function decimals() external pure returns (uint8) {
    return uint8(0); // Placeholder value
  }

  function maxMint(address) external pure returns (uint256 maxShares) {
    return uint256(0); // Placeholder value
  }

  function maxRedeem(address) external pure returns (uint256 maxShares) {
    return uint256(0); // Placeholder value
  }

  function mint(uint256, address) external pure returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function name() external pure returns (string memory) {
    return ""; // Placeholder value
  }

  function nonces(address) external pure returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function previewMint(uint256) external pure returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function previewRedeem(uint256) external pure returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function redeem(uint256, address, address) external pure returns (uint256 assets) {
    return uint256(0); // Placeholder value
  }

  function symbol() external pure returns (string memory) {
    return ""; // Placeholder value
  }

  function totalSupply() external pure returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function transfer(address, uint256) external pure returns (bool) {
    return true; // Placeholder value
  }

  function transferFrom(address, address, uint256) external pure returns (bool) {
    return true; // Placeholder value
  }
}
