# CI supply-chain controls

This document describes the GitHub Actions hardening used by
[`tests.yml`](https://github.com/covenant-gov/pacto-squad-sponsor/blob/dev/.github/workflows/tests.yml),
[`coverage.yml`](https://github.com/covenant-gov/pacto-squad-sponsor/blob/dev/.github/workflows/coverage.yml),
[`natspec.yml`](https://github.com/covenant-gov/pacto-squad-sponsor/blob/dev/.github/workflows/natspec.yml),
[`canary.yml`](https://github.com/covenant-gov/pacto-squad-sponsor/blob/dev/.github/workflows/canary.yml),
[`release.yml`](https://github.com/covenant-gov/pacto-squad-sponsor/blob/dev/.github/workflows/release.yml),
and the local composite
[`install-tools`](https://github.com/covenant-gov/pacto-squad-sponsor/blob/dev/.github/workflows/install-tools/action.yml).

## Controls in place

| Control | Behavior |
|---|---|
| Action pins | Third-party `uses:` entries are full commit SHAs with a trailing version comment (for example `# v6.1.0`). Nested actions inside the local `install-tools` composite are pinned the same way. |
| Default permissions | Workflows set `permissions: contents: read`. The coverage comment job restates `contents: read` and adds `pull-requests: write`. |
| Checkout credentials | `persist-credentials: false` on checkouts that do not need default git remote credentials. |
| Package install | `pnpm install --frozen-lockfile --ignore-scripts` in `install-tools` (and coverage via that composite). Root and git dependency `prepare` scripts are husky-only; CI does not need them. Builds remain constrained by `pnpm.onlyBuiltDependencies`. |
| Secret isolation | `MAINNET_RPC` is injected only on integration fork-test steps after dependency install. Unused workflow-level `ARBITRUM_RPC` / `SEPOLIA_RPC` CI env bindings were removed. |
| Trusted PR / release separation | Coverage and natspec run on `pull_request` without publish secrets. Canary (`workflow_dispatch`) and production release (`release: published`) stay gated with `if: false` (publishing disabled). CI unit/lint/integration remain on `push`. |

Dependabot watches the `github-actions` ecosystem so SHA pins can be refreshed through normal dependency PRs.

## Publishing status (unchanged)

Canary and production NPM export jobs remain **disabled** (`if: false`). Enabling them later requires an explicit maintainer change, plus least-privilege publish scopes (`packages` / registry auth) on those jobs only—not on PR workflows.

## What this does not change

- Foundry version used in CI (`v1.5.1` via `install-tools`)
- Unit, gas snapshot, integration, lint, bulloak, natspec, and coverage gates
- Disabled canary/release publishing
- Contract and test behavior
- No CODEOWNERS file exists in this repository; none was invented
