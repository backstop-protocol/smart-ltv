// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

contract SPythia {
    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    bytes32 constant public EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );    

    struct RiskData {
        address collateralAsset;
        address debtAsset;
        uint256 liquidity;
        uint256 volatility;
        uint256 lastUpdate;
        uint256 chainId;
    }

    bytes32 constant public RISKDATA_TYPEHASH = keccak256(
        "RiskData(address collateralAsset,address debtAsset,uint256 liquidity,uint256 volatility,uint256 lastUpdate,uint256 chainId)"
    );

    bytes32 immutable public DOMAIN_SEPARATOR;
    
    uint256 immutable public chainId;

    constructor () {
        chainId = block.chainid;

        DOMAIN_SEPARATOR = hashStruct(EIP712Domain({
            name: "SPythia",
            version: '0.0.1',
            chainId: chainId,
            verifyingContract: address(this)
        }));
    }

    function hashStruct(EIP712Domain memory eip712Domain) public pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    function hashStruct(RiskData memory data) public pure returns (bytes32) {
        return keccak256(abi.encode(
            RISKDATA_TYPEHASH,
            data.collateralAsset,
            data.debtAsset,
            data.liquidity,
            data.volatility,
            data.lastUpdate,
            data.chainId
        ));
    }

    function getSigner(RiskData memory data, uint8 v, bytes32 r, bytes32 s) public view returns (address) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hashStruct(data)
        ));
        return ecrecover(digest, v, r, s);
    }
}