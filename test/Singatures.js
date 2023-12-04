const { expect } = require("chai");
const ethers = require("ethers")
const hre = require("hardhat");

const toWei = function(n) {
  return ethers.parseUnits(n,"ether")
}

const fromWei = function(n) {
  return Number(ethers.formatEther(n,toString()))
}


const typedData = {
  types: {
      RiskData: [
          { name: 'collateralAsset', type: 'address' },
          { name: 'debtAsset', type: 'address' },
          { name: 'liquidity', type: 'uint256' },
          { name: 'volatility', type: 'uint256' },
          { name: 'lastUpdate', type: 'uint256' },                    
          { name: 'chainId', type: 'uint256' }
      ]
  },


  primaryType: 'RiskData',
  domain: {
      name: 'SPythia',
      version: '0.0.1',
      chainId: 5,
      verifyingContract: '0xa9aCE3794Ed9556f4C91e1dD325bC5e4AB1CCDE7',
  },
  value: {
    collateralAsset: "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826",
    debtAsset: "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB",
    liquidity: toWei("10000"),
    volatility: toWei("0.1"),
    lastUpdate: "666", // this will be override
    chainId: 7 // this will be override
  },
};

describe("SPythia", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContracts(relayerAddress) {
    const SPythia = await hre.ethers.getContractFactory("SPythia");
    const SSmartLTV = await hre.ethers.getContractFactory("SSmartLTV");    

    const spythia = await SPythia.deploy();
    const smartLTV = await SSmartLTV.deploy(spythia.target, relayerAddress)

    return {spythia, smartLTV};
  }

  describe("SPythia", function () {
    it("test", async function () {
      // this is not a safe private key, don't use in production !!!!!!!!!
      const privateKey = "0x0123456789012345678901234561890123456789012345678901234567890123"
      const walletPrivateKey = new ethers.Wallet(privateKey)


      const {spythia, smartLTV} = await deployContracts(walletPrivateKey.address);
      
      const chainId = await spythia.chainId()

      typedData.domain.chainId = parseInt(chainId)
      typedData.domain.verifyingContract = spythia.target

      typedData.value.chainId = parseInt(chainId)
      typedData.value.lastUpdate = Math.floor(Date.now() / 1000)

      /*
      const mnemonic = "announce room limb pattern dry unit scale effort smooth jazz weasel alcohol"
      const walletMnemonic = Wallet.fromMnemonic(mnemonic)
      */
      // ...or from a private key
      //const walletPrivateKey = ethers.Wallet.createRandom()

      const signature = await walletPrivateKey.signTypedData(typedData.domain, typedData.types, typedData.value)
      const splitSig = ethers.Signature.from(signature)
      const signer = await spythia.getSigner(
        typedData.value,
        splitSig.v,
        splitSig.r,
        splitSig.s
      )

      expect(signer, walletPrivateKey.address)

      console.log("calculating LTV")
      const clf = toWei("0.1")
      const debt = toWei("1000000")
      const beta = toWei("0.05")

      const ltv = await smartLTV.ltv(
        typedData.value.collateralAsset,
        typedData.value.debtAsset,
        debt,
        beta,
        clf,
        typedData.value,
        splitSig.v,
        splitSig.r,
        splitSig.s
      )

      const expectedLTV = Math.exp(
        -1 * fromWei(clf) * fromWei(typedData.value.volatility) / Math.sqrt(fromWei(typedData.value.liquidity) / fromWei(debt))
      ) - fromWei(beta)
        
      // allow for some rounding errors
      expect(fromWei(ltv) / expectedLTV < 1.000001 && fromWei(ltv) / expectedLTV > 0.9999999).to.be.true
      
      console.log({ltv}, toWei(expectedLTV.toString()))
    });
  });

  //403.74165

});
