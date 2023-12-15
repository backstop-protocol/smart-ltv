// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "../../lib/metamorpho/lib/morpho-blue/src/interfaces/IMorpho.sol";

contract MockMorpho is IMorpho {
  // Mock state variables
  mapping(Id => Market) public marketInfos;
  mapping(Id => mapping(address => Position)) public positionInfos;

  // Setters for mock data
  function setMarketInfo(Id marketId, Market memory marketInfo) external {
    marketInfos[marketId] = marketInfo;
  }

  function setPosition(Id marketId, address user, Position memory positionInfo) external {
    positionInfos[marketId][user] = positionInfo;
  }

  function position(Id id, address user) external view returns (Position memory p) {
    return positionInfos[id][user];
  }

  function market(Id id) external view returns (Market memory m) {
    return marketInfos[id];
  }

  function idToMarketParams(Id) external pure override returns (MarketParams memory) {
    return MarketParams(address(0), address(0), address(0), address(0), 0); // Placeholder value
  }

  function DOMAIN_SEPARATOR() external pure override returns (bytes32) {
    return bytes32(0); // Placeholder value
  }

  function owner() external pure override returns (address) {
    return address(0); // Placeholder value
  }

  function feeRecipient() external pure override returns (address) {
    return address(0); // Placeholder value
  }

  function isIrmEnabled(address) external pure override returns (bool) {
    return false; // Placeholder value
  }

  function isLltvEnabled(uint256) external pure override returns (bool) {
    return false; // Placeholder value
  }

  function isAuthorized(address, address) external pure override returns (bool) {
    return false; // Placeholder value
  }

  function nonce(address) external pure override returns (uint256) {
    return uint256(0); // Placeholder value
  }

  function setOwner(address) external override {
    // Placeholder body
  }

  function enableIrm(address) external override {
    // Placeholder body
  }

  function enableLltv(uint256) external override {
    // Placeholder body
  }

  function setFee(MarketParams memory, uint256) external override {
    // Placeholder body
  }

  function setFeeRecipient(address) external override {
    // Placeholder body
  }

  function createMarket(MarketParams memory) external override {
    // Placeholder body
  }

  function supply(
    MarketParams memory,
    uint256,
    uint256,
    address,
    bytes memory
  ) external pure override returns (uint256, uint256) {
    return (uint256(0), uint256(0)); // Placeholder values
  }

  function withdraw(
    MarketParams memory,
    uint256,
    uint256,
    address,
    address
  ) external pure override returns (uint256, uint256) {
    return (uint256(0), uint256(0)); // Placeholder values
  }

  function borrow(
    MarketParams memory,
    uint256,
    uint256,
    address,
    address
  ) external pure override returns (uint256, uint256) {
    return (uint256(0), uint256(0)); // Placeholder values
  }

  function repay(
    MarketParams memory,
    uint256,
    uint256,
    address,
    bytes memory
  ) external pure override returns (uint256, uint256) {
    return (uint256(0), uint256(0)); // Placeholder values
  }

  function supplyCollateral(MarketParams memory, uint256, address, bytes memory) external override {
    // Placeholder body
  }

  function withdrawCollateral(MarketParams memory, uint256, address, address) external override {
    // Placeholder body
  }

  function liquidate(
    MarketParams memory,
    address,
    uint256,
    uint256,
    bytes memory
  ) external pure override returns (uint256, uint256) {
    return (uint256(0), uint256(0)); // Placeholder values
  }

  function flashLoan(address, uint256, bytes calldata) external override {
    // Placeholder body
  }

  function setAuthorization(address, bool) external override {
    // Placeholder body
  }

  function setAuthorizationWithSig(Authorization calldata, Signature calldata) external override {
    // Placeholder body
  }

  function accrueInterest(MarketParams memory) external override {
    // Placeholder body
  }

  function extSloads(bytes32[] memory) external pure override returns (bytes32[] memory) {
    return new bytes32[](0); // Placeholder value
  }
}
