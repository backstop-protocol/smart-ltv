const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");


const toWei = function(n) {
  return ethers.parseUnits(n,"ether")
}

describe("Smart LTV", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContracts() {
    // Contracts are deployed using the first signer/account by default
    const [owner, relayer] = await ethers.getSigners();

    const Pythia = await ethers.getContractFactory("Pythia");
    const KeyEncoder = await ethers.getContractFactory("KeyEncoder");
    const SmartLTV = await ethers.getContractFactory("SmartLTV");

    const pythia = await Pythia.deploy();
    const keyEncoder = await KeyEncoder.deploy();

    //console.log(pythia.target, relayer.address)
    const smartLTV = await SmartLTV.deploy(/*pythia.target, relayer.address*/);


    return {smartLTV, pythia, keyEncoder, relayer};
  }

  describe("check LTV", function () {
    it("test", async function () {
      const {smartLTV, pythia, keyEncoder, relayer} = await deployContracts();

      const collateral = "0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5"
      const debt = "0xe688b84b23f322a994A53dbF8E15FA82CDB71127"

      const liqIncentive = toWei("0.05")

      const now = Math.floor(+new Date() / 1000)

      // 1) set liquidity
      const liquidityKey = await keyEncoder.encodeLiquidityKey(collateral, debt, 0, liqIncentive, 60 * 60 * 24 * 365);
      await pythia.connect(relayer).set(collateral, liquidityKey, toWei("100000"), now)

      // 2) set volatility
      const volatilityKey = await keyEncoder.encodeVolatilityKey(collateral, debt, 0, 60 * 60 * 24 * 365);
      await pythia.connect(relayer).set(collateral, volatilityKey, toWei("21.8"), now)

      // test liquidity
      expect(await smartLTV.getVolatility(collateral, debt)).to.equal(toWei("21.8"));

      // test volatility
      expect(await smartLTV.getLiquidity(collateral, debt, liqIncentive)).to.equal(toWei("100000"));

      const res = await smartLTV.ltv(collateral, debt)
      console.log(res.toString())

      expect(res).to.equal("617816629358139653");
    });
  });

  //403.74165

});
