# pacto-squad-sponsor

Collective, squad-scoped ETH gas sponsorship for [Pacto](https://github.com/covenant-gov).

Squads fund a **shared gas pool**. Eligible members use the Pacto app without holding ETH. This repo pays **gas only** — action permission stays in [pacto-gov](https://github.com/covenant-gov/pacto-gov). Transport is ERC-4337 (`PactoSponsorPaymaster`) plus EIP-7702 for roster EOAs.

v1 targets Ethereum Mainnet, Sepolia, and Arbitrum One.

## Contracts

| Contract | Role |
|----------|------|
| [`SquadSponsorFactory`](src/contracts/SquadSponsorFactory.sol) | Chain singleton. Deploys per-parent pools, per-squad eligibility clones, and the wired paymaster. |
| [`SquadSponsorPool`](src/contracts/SquadSponsorPool.sol) | Per-parent ETH vault (shares, `spendGas`, `defacto` / `wargame` slots). |
| [`PactoSponsorPaymaster`](src/contracts/PactoSponsorPaymaster.sol) | ERC-4337 EntryPoint v0.7 paymaster. Spends from the parent pool when the clone occupies a slot. |
| [`SquadSponsorExt`](src/contracts/SquadSponsorExt.sol) | Address-based eligibility. Typical live path before Hats exist (`defacto`). |
| [`SquadSponsor`](src/contracts/SquadSponsor.sol) | Hat-based eligibility (hat-first clone, Ext after `postInitialize`, or war-game round). |
| [`PactoSimple7702Account`](src/contracts/PactoSimple7702Account.sol) | Pacto-owned EIP-7702 account implementation. |

Each parent squad gets one primary pool per chain (optional extra pools via `createFreshPool`). Eligibility clones hold no ETH. `SquadSponsorExt.postInitialize` wires Hats on that clone (one-way; hats override the address list). War-game rounds use `createWarGameSponsor` after `deployNavePirata` and never occupy production `squadId`.

## Docs

- [`docs/TECH_SPEC.md`](docs/TECH_SPEC.md) — product, architecture, and locked design decisions
- [`docs/DESKTOP_CLIENT_INTEGRATION.md`](docs/DESKTOP_CLIENT_INTEGRATION.md) — ERC-4337 / 7702 client guide for `pacto-app`
- [`docs/PACTO_GOV_FOLLOWUPS.md`](docs/PACTO_GOV_FOLLOWUPS.md) — wiring required in pacto-gov

Sepolia addresses: [`deployments/11155111/full-system.json`](deployments/11155111/full-system.json) and [`deployments/11155111/eip7702-account.json`](deployments/11155111/eip7702-account.json).

## Setup

1. Install Foundry from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy `.env.example` to `.env` and fill in the variables.
3. Install rust tools with [cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html):
   1. `cargo install lintspec`
   2. `cargo install bulloak`
4. Install dependencies: `pnpm install`. If commands fail, run `foundryup` and retry.

## Build

```bash
pnpm build
```

Optimized IR build:

```bash
pnpm build:optimized
```

## Tests

Unit tests are isolated. Integration (E2E) tests fork **mainnet**.

```bash
pnpm test
```

```bash
pnpm test:unit
```

```bash
pnpm test:unit:deep
```

```bash
pnpm test:integration
```

```bash
pnpm coverage
```

Scaffold or fix Bulloak trees:

```bash
pnpm test:bulloak:scaffold
pnpm test:bulloak:fix
```

## Deploy & verify

Configure `.env` and source it:

```bash
source .env
```

Import deployer keys into Foundry’s encrypted keystore:

```bash
cast wallet import $MAINNET_DEPLOYER_NAME --interactive
cast wallet import $SEPOLIA_DEPLOYER_NAME --interactive
cast wallet import $ARBITRUM_DEPLOYER_NAME --interactive
```

Deploy the EIP-7702 account first, then the sponsor system (allowlist resolves from `eip7702-account.json`, or set `PACTO_7702_ACCOUNT`):

```bash
pnpm deploy:7702:sepolia
pnpm deploy:sepolia
```

```bash
pnpm deploy:7702:arbitrum
pnpm deploy:arbitrum
```

```bash
pnpm deploy:7702:mainnet
pnpm deploy:mainnet
```

To fund EntryPoint deposit + FCFS stake on an **already-deployed** paymaster (does not redeploy; addresses from `full-system.json`):

```bash
pnpm simulate-fund:paymaster:sepolia
pnpm fund:paymaster:sepolia
```

If a live paymaster was deployed with a zero 7702 allowlist, cut over (redeploy factory + paymaster, fund deposit/stake; does not redeploy 7702). Do **not** use cutover to top up the live Sepolia paymaster.

```bash
pnpm cutover:paymaster:sepolia
```

Artifacts: `deployments/<chainId>/eip7702-account.json` and `deployments/<chainId>/full-system.json`. Broadcast traces are under `./broadcast`.

See the [Foundry Book](https://book.getfoundry.sh/reference/forge/forge-create.html) for extra `forge` options.

## License

MIT. See [`LICENSE`](LICENSE).

Scaffolded from the [Wonderland Foundry boilerplate](https://github.com/defi-wonderland/solidity-foundry-boilerplate).
