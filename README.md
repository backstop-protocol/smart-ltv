# Smart LTV

Smart LTV is a Solidity-based project focused on optimizing loan-to-value calculations and risk management in decentralized finance. It integrates advanced algorithms for efficient market allocation and data verification using EIP712 standards.

## Installation

To set up the project, you'll need Foundry and NodeJS installed

`npm install`

## Scripts

### Test Unit: Run unit tests with the command:


`npm run test-unit`

### Test Integration: Execute integration tests on a Goerli testnet fork:

```
export GOERLI_RPC_URL=<your-goerli-rpc-url>
npm run test-integration
```

### Coverage: Generate and view coverage reports:

`npm run coverage`

### Build: Compile the smart contracts:

`npm run build`

### Prettier-Format: Format your Solidity files:

`npm run prettier-format`

### Prettier-Watch: Auto-format Solidity files on changes:

`npm run prettier-watch`

## Development

This project uses Foundry for smart contract development. Follow these best practices:

- Compile contracts with forge build.
- Write unit tests in test/unit and integration tests in test/integration.
- Ensure code quality by using Prettier for formatting.

## Contributions

Contributions are welcome! Please ensure you follow the testing and coding standards mentioned above.
