# Pacto Squad Sponsor — Technical Specification

**Status:** Draft (implementation-ready)  
**Repo:** [covenant-gov/pacto-squad-sponsor](https://github.com/covenant-gov/pacto-squad-sponsor)  
**Companion repo:** [covenant-gov/pacto-gov](https://github.com/covenant-gov/pacto-gov) (Nave Pirata governance)  
**Target chains (v1):** Ethereum Mainnet (`1`), Sepolia (`11155111`), Arbitrum One (`42161`)  
**Testing:** integration/e2e forks **mainnet**; Sepolia is **frontend live testing** against deployed contracts (D19)
**Solidity:** `0.8.30` (match pacto-gov)  
**License:** MIT  

---

## 0. Purpose of this document

This spec is written for an **implementing agent** working in **pacto-squad-sponsor** with no prior chat context. It defines:

- Product and security goals for **collective, squad-scoped gas sponsorship**
- On-chain architecture (**one minimal-proxy clone per squad** — pool + eligibility in `SquadSponsorBase`; no separate vault contract)
- Off-chain relayer integration (Alchemy v1; pluggable later)
- How sponsorship relates to **pacto-gov** via **`SquadSponsorExt.postInitialize`**
- **Executable milestones** through testnet and mainnet

**Out of scope for pacto-squad-sponsor v1:** Governance logic in pacto-gov ( **`PactoAdmin`**, factory wiring — tracked in [`PACTO_GOV_FOLLOWUPS.md`](./PACTO_GOV_FOLLOWUPS.md)). **Crew hat mint sponsorship** (captain-controlled; not v1). **On-chain balance alerts** (app-side only).

**Desktop / `pacto-app` integration:** Normative client guide, golden vectors, and encoder helpers live in [`DESKTOP_CLIENT_INTEGRATION.md`](./DESKTOP_CLIENT_INTEGRATION.md) (issue [#5](https://github.com/covenant-gov/pacto-squad-sponsor/issues/5)).

---

## 1. Product summary

### 1.1 Collective paradigm

Pacto squads are **groups that trust each other** and coordinate via roles (captain, crew, treasury, mutiny, app admin). On-chain governance uses **Hats Protocol** — wearers are addresses (EOAs or contracts).

**Goal:** One or more members fund a **shared gas pool** per squad. Members use the **Pacto app** without holding ETH or understanding gas. Any **permitted in-squad action** — including **deploying squad infrastructure** (PactoGov, Gnosis Safe, etc.) — is submitted via a **relayer + paymaster** when the squad pool can cover it.

This is intentionally **not** per-user gas abstraction. It is **squad-collective** sponsorship.

### 1.2 Independence from pacto-gov

| Layer | Repo | Role |
|--------|------|------|
| Rules & modules | **pacto-gov** | `Quartermaster`, `MutinyModule`, `TreasuryAuthority`, `SquadAdmin`, **`PactoAdmin`**, `NavePirataFactory`, `NavePirataRegistry` |
| Gas pools, eligibility modules, **ERC-4337 paymaster** | **pacto-squad-sponsor** | **`SquadSponsorFactory`**, **`PactoSponsorPaymaster`** (ERC-4337), **`SquadSponsorExt`** (address primitive), **`SquadSponsor`** (hats) |
| Transport (bundler / relay) | **Alchemy** (v1) | `eth_sendUserOperation`, Gas Manager → paymaster |
| UX | **Pacto app** | Keys (Nostr → EVM), UserOps (**ERC-4337**) + **EIP-7702** delegation, squad inbox |

**Modular pattern (mirrors `SquadAdmin` / `SquadAdminExt` in pacto-gov):**

| Contract | When deployed | Eligibility | 
|----------|---------------|-------------|
| **`SquadSponsorExt`** | **Typical first path** via `createSquadSponsorExt` | **Address-based** — members who shared EVM with squad (app-synced; no Hats) |
| **`SquadSponsor`** | **`createSquadSponsor`** when hats known at bootstrap, or hat rules after Ext `postInitialize` | **Hat-based** — wearers of configured squad hats (e.g. crew + captain for PactoGov) |

**`SquadSponsorExt` is deployed before pacto-gov.** It is the primitive expansion for address access control (no Hats, no plugin infra). **`SquadSponsor` base** is the Hats path — deployed with gov or a custom tree.

**Wiring:** When hats become available, **`SquadSponsorExt.postInitialize`** wires hat eligibility **on the same clone** (inherits `SquadSponsor`; `topHatId != 0` ⇒ hat rules override address list). Alternatively, deploy a hat-first **`SquadSponsor`** clone via `createSquadSponsor` when hats are known upfront.

**Callers of `postInitialize`:** `NavePirataFactory`, contract **owner**, or **Hats tree owner** — match `SquadAdminExt` auth in pacto-gov (see [`PACTO_GOV_FOLLOWUPS.md`](./PACTO_GOV_FOLLOWUPS.md)).

**No duplicate registries:** Address lists for sponsor gas live **only** in `SquadSponsorExt`. pacto-gov must not mirror them (QM crew state ≠ sponsor eligibility). When hats are wired, read Hats via base — do not maintain parallel address lists in gov.

**Undecided (note):** `SquadAdmin` contracts may move to a shared repo; sponsor modules should remain composable the same way.

**v1 eligibility modes (full feature set):** (1) address via Ext, (2) PactoGov hat tree via base + `postInitialize`, (3) custom / arbitrary Hats tree via base + `postInitialize` — not an admin toggle; determined by what has been deployed and wired.

### 1.3 What is sponsored (v1)

| Category | Gas sponsored? | Notes |
|----------|----------------|--------|
| Any squad action in **Pacto app UX** | **Yes** | Eligible member (§4.3) + pool balance |
| **Infrastructure deploy** (PactoGov, Safe, etc.) | **Yes** | `PactoAdmin` permission; sponsor pays gas |
| Permissionless gov `execute*` via app | **Yes** | Target enforces rules |
| **Crew hat mint** | **No (v1)** | Captain-controlled; deferred |
| Raw ETH / arbitrary calls | **No** | App never relays |

**Rule of thumb:** Eligible member + funded pool → gas covered. Action permission stays in **`PactoAdmin`** / target contracts (§1.4).

### 1.4 Permissions vs gas (critical separation)

**Two independent concerns:**

| Concern | Owner | Question |
|---------|--------|----------|
| **Permission** | **`PactoAdmin`** (pacto-gov) + target contracts | May this member perform this action (deploy gov, deploy Safe, crew vote, etc.)? |
| **Gas** | **pacto-squad-sponsor** | Will the squad pool pay for this UserOp’s gas? |

**Invariants:**

1. **Permission first, gas second.** If a member **lacks permission**, the transaction reverts or is never built — **gas sponsorship is irrelevant**.
2. **Permission granted → gas assumed covered** for **eligible** members when the pool has sufficient balance.
3. **The sponsor never grants action permission.** It only pays gas.
4. **Eligibility follows deployment wiring on that clone** — Ext (addresses) until `postInitialize` connects hat base; then hats override. War-game rounds are separate clones.

```mermaid
flowchart LR
  App[Pacto app builds UserOp]
  PA[PactoAdmin / target: allowed action?]
  Elig{Ext or Base: eligible?}
  Pool[Squad pool: sufficient balance?]
  PM[Paymaster sponsors gas]

  App --> PA
  PA -->|no permission| Reject[No tx / revert — gas N/A]
  PA -->|permitted| Elig
  Elig -->|not eligible| Reject2[Paymaster rejects]
  Elig -->|eligible| Pool
  Pool -->|insufficient| Reject3[Paymaster rejects]
  Pool -->|funded| PM
```

### 1.5 Account abstraction strategy

| Signer account | Detection | Transport |
|----------------|-----------|-----------|
| **EOA** (seed-derived) | `code.length == 0` or `0xef0100 \|\| impl` delegation stub | **EIP-7702** (one-time set-code) + **ERC-4337** UserOp + paymaster |
| **Gnosis Safe** (pause-captain, treasury) | Safe address with **4337 module enabled** | **ERC-4337** UserOp with **`userOp.sender` = Safe** + paymaster (§5.2) |
| **Contract wallet** (other smart accounts) | `code.length > 0` (not delegation-only) | **ERC-4337** UserOp; resolve signer per account implementation |

**v1 supports both EOAs and contract wallets.** Paymaster resolves the **beneficiary member** from `paymasterAndData` (see §4.2):

- Empty-code EOA ⇒ `sender == member`.
- EIP-7702 designated code (`0xef0100 || impl`) ⇒ `sender == member` **and** `impl == ALLOWED_7702_IMPLEMENTATION` (immutable on the paymaster; set via `SquadSponsorFactory` ctor / `PACTO_7702_ACCOUNT`).
- Other smart accounts (e.g. Safe) ⇒ `member` in payload only (signer → `member` mapping **deferred**).

**EIP-7702 set-code target:** Pacto-owned [`PactoSimple7702Account`](../src/contracts/PactoSimple7702Account.sol) — storage-free, EntryPoint v0.7 hardcoded, bare ECDSA over `userOpHash`. Publish address in `deployments/<chainId>/eip7702-account.json`. Do **not** use eth-infinitism Simple7702Account (EP v0.8) or Alchemy SemiModularAccount7702.

References:

- [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) — Set code for EOAs (Pectra)
- [EIP-4337](https://eips.ethereum.org/EIPS/eip-4337) — Account abstraction
- [Alchemy Account Abstraction](https://www.alchemy.com/account-abstraction) / [Bundler docs](https://docs.alchemy.com/reference/bundler-api-quickstart)

---

## 2. Locked design decisions

| # | Decision |
|---|----------|
| D1 | **One production sponsor clone per parent `squadId`** (minimal proxy) — pool + eligibility in `SquadSponsorBase`; each clone’s ETH isolated. War-game rounds are **additional** Ext clones under derived ids (see §4.0). |
| D2 | **ETH only** — no ERC-20 gas payment in v1 |
| D3 | **Multi-sponsor pro-rata** accounting per squad clone (deposit shares; withdraw proportional to remaining pool) |
| D4 | Depositors may **withdraw** unspent share; gas spend reduces everyone’s withdrawable amount proportionally — **owner cannot withdraw others’ deposits** |
| D5 | **Permissions ≠ gas** — action permission (`PactoAdmin`, target contracts) is separate from gas payment (this repo) |
| D6 | **Unmapped funds:** explicit `deposit` only; orphan ETH recoverable via `saviourWithdraw` on implementation / factory policy |
| D7 | **Not upgradeable** — new policy = new paymaster + new implementation if ever needed |
| D8 | **Deployment-driven eligibility** — Ext (address) until hat base wired via `postInitialize`; no admin mode toggle |
| D9 | Relayer v1: **Alchemy** bundler + Gas Manager → **ERC-4337** paymaster |
| D10 | **One clone per registered `squadId`:** `SquadSponsorExt` (address-first) or `SquadSponsor` (hat-first); Ext `postInitialize` wires hats on **that** clone. Production uses `keccak256(parentId)`; each war-game round uses `warGameSquadId(parentSquadId, round)` |
| D11 | **Hat wiring overrides** addresses (and prior custom hat config) — one-way `postInitialize` |
| D12 | **v1 eligibility paths:** address (Ext), PactoGov hats, custom Hats tree (same `postInitialize` pattern as **`PactoAdmin`**) |
| D13 | **EOA + contract wallets** via 7702 + 4337; **Gnosis Safe** as **ERC-4337 smart account** (Safe 4337 plugin — §5.2) |
| D18 | **Safe transport (locked):** Path **A** — Safe is `userOp.sender` via official / compatible **ERC-4337 Safe module**; not Safe SDK relay (B) or module-only EOA workaround (C) |
| D19 | **Integration / e2e fork mainnet** — Sepolia is deploy + frontend live testing only (§11) |
| D14 | **Three chains v1:** Mainnet (`1`), Sepolia (`11155111`), Arbitrum One (`42161`) |
| D15 | **Low-balance UX alerts** — app only |
| D16 | **`addressOwner` = first depositor** (“early bird”); role is eligibility admin only — **not** pool custody |
| D17 | **`addressOwner` transferable** — current owner may `transferAddressOwner(newOwner)` (§4.3.4) |

---

## 3. System architecture

```mermaid
flowchart TB
  subgraph app [Pacto App]
    Keys[EOA from Nostr seed]
    UX[Squad UX actions]
  end

  subgraph sponsor [pacto-squad-sponsor]
    Factory[SquadSponsorFactory]
    SponsorClone[Sponsor clone per squad Ext or Sponsor]
    PM[PactoSponsorPaymaster ERC-4337]
  end

  subgraph gov [pacto-gov - optional]
    Reg[NavePirataRegistry]
    Factory[NavePirataFactory]
    Mods[QM / MM / TA / SquadAdmin clones]
  end

  subgraph relay [Alchemy]
    Bundler[Bundler / Gas Manager]
  end

  UX --> Keys
  Keys -->|sign UserOp / 7702 auth| Bundler
  Bundler --> PM
    Factory -->|createSquadSponsorExt / createSquadSponsor / createWarGameSponsorExt| SponsorClone
  PM -->|spendGas| SponsorClone
  Factory -->|postInitialize wires hats on Ext clone| SponsorClone
  PM -->|Safe 4337 UserOp| Mods
```

**Execution invariant:** For hat-gated functions, **`msg.sender` must be the member EOA** (or valid contract wearer). The paymaster **never** calls `crewVote` as itself to “proxy” a vote.

**Policy invariant:** Eligibility is evaluated on the **registered sponsor clone** for `squadId` — `SquadSponsorExt` uses address list until `topHatId != 0`, then hat rules on the same clone. Paymaster is **ERC-4337**; transport via bundler (§6.1). See [`PACTO_GOV_FOLLOWUPS.md`](./PACTO_GOV_FOLLOWUPS.md) for factory wiring.

---

## 4. On-chain contracts

### 4.0 `SquadSponsorFactory` + per-squad clones

**Problem:** A single chain-wide pool holding all squads’ ETH is a larger honeypot. **v1 uses one minimal-proxy clone per registered `squadId`** (pool + eligibility in `SquadSponsorBase`). Production gov is one clone per parent. War-game replays mint **another** Ext clone per round so each tree can `postInitialize` without rewiring production.

**`SquadSponsorFactory`** (chain singleton, CREATE2-deployed with `PactoSponsorPaymaster`):

- `createSquadSponsorExt(bytes32 squadId, address addressOwner)` → **Ext clone**; optional ETH → pro-rata deposit. Production `squadId` = `keccak256(parentId)`.
- `createSquadSponsor(...)` → hat-first clone when top hat known.
- `createWarGameSponsorExt(parentSquadId, addressOwner)` → next-round Ext clone at `warGameSquadId(parentSquadId, round)` (`keccak256(abi.encode(parent, WAR_GAME_NS, round))`, rounds start at 1). CREATE2 salt = `gameSquadId`. Does **not** register or wire `parentSquadId`. Same `postInitialize` as real gov, **once per round clone**.
- **FCFS paymaster stake ops (MVP):** `addPaymasterStake` / `unlockPaymasterStake` / `withdrawPaymasterStake` / `withdrawPaymasterDeposit`. Single `paymasterStaker` slot; initial stake ≥ `0.1 ether` and delay ≥ `1 days`. Staker controls EP stake lifecycle and `withdrawTo` forwards. Anyone may still call `paymaster.deposit()` directly.
- `createSquadSponsor(bytes32 squadId, topHatId, registry, customEligibleHats)` → **hat-first Sponsor clone** when hats are known at bootstrap.
- Registry: `squadId` → `{ sponsor, variant, topHatId }`; `squadIdBySponsor` reverse lookup; `warGameRoundCount(parentSquadId)`; `predictWarGameSponsor(parent, round)`.
- `hats()` returns `SquadSponsorConstants.HATS_ADDRESS` (not a constructor arg).
- Immutable `PAYMASTER` wired into every clone at `initialize`.

Paymaster is a **chain singleton**; `paymasterAndData` includes `squadId`, **sponsor clone address**, and **member** (§4.2).

### 4.1 `SquadSponsorBase` (abstract — pool in every clone)

Each clone holds **one squad’s ETH only** (`squadId`, `paymaster`, `factory` set at init).

**Responsibilities (per clone):**

1. Hold ETH for **this squad** only.
2. Track **sponsor shares** (pro-rata `deposit` / `withdraw`).
3. Expose `spendGas` **only** to the wired paymaster.
4. Virtual `_isEligible(member)` — implemented by `SquadSponsorExt` or `SquadSponsor`.

**First deposit / early bird (Ext path):**

- On **`createSquadSponsorExt`**, **`msg.sender` becomes `addressOwner`** on the Ext clone (D16).
- Optional `msg.value` on create → `depositFor(msg.sender)` via factory helper.

**Accounting (pro-rata)** — scoped to single clone:

```
On deposit / depositFor:
  mint shares pro-rata → credit sponsorShares[sponsor]

On withdraw():
  burn shares pro-rata → transfer ETH to msg.sender

On spendGas(amount):  // only paymaster
  transfer amount ETH to paymaster
```

### 4.2 `PactoSponsorPaymaster` (ERC-4337 verifying paymaster)

**Non-upgradeable.** Immutable constructor args (as implemented):

- `IEntryPoint entryPoint`
- `SquadSponsorFactory factory` (anti-spoof registry lookup)

Hats is **not** a paymaster constructor arg — eligibility reads Hats via sponsor clone bytecode (`SquadSponsorConstants`).

Per-UserOp **`paymasterAndData`** (after standard 52-byte ERC-4337 header):

```solidity
abi.encode(uint8 version, bytes32 squadId, address sponsor, address member)
// version = PAYMASTER_DATA_VERSION (1)
```

**`validatePaymasterUserOp` (as implemented):**

1. Decode `squadId`, `sponsor`, `member` from `paymasterAndData`.
2. **`_validateRegistry`** — `factory.squads(squadId).sponsor == sponsor`.
3. Check `sponsor.spendablePoolWei() >= maxCost × 115%` headroom (storage-backed; no `BALANCE` opcode).
4. **Member binding / 7702 allowlist:**
   - EOA (`code.length == 0`): require `sender == member`.
   - EIP-7702 stub (`0xef0100 || impl`, 23 bytes): require `sender == member` and `impl == ALLOWED_7702_IMPLEMENTATION` (else `SS_Invalid7702Implementation`).
   - Other smart accounts: skip binding (Safe signer mapping **deferred**).
5. **`sponsor.isEligible(member)`** — Ext address list or hat rules on same clone.
6. `postOp` (success only) → `sponsor.spendGas(actualGasCost)`.

**Deferred (spec target, not yet in contract):** Safe 4337 signer → `member` validation; calldata allowlists; per-class gas caps.

**Implemented for 7702:** `ALLOWED_7702_IMPLEMENTATION` on `PactoSponsorPaymaster` (factory constructor arg).
### 4.3 `SquadSponsorExt` + `SquadSponsor` clones (mirrors `SquadAdminExt` + `SquadAdmin`)

**One minimal-proxy clone per squad** — pool and eligibility live on the same contract (`SquadSponsorBase`). `SquadSponsorExt` inherits `SquadSponsor` for hat wiring via `postInitialize` on the **same** address.

**Custom Hats tree (no full PactoGov):** same **`postInitialize`** auth pattern as `SquadAdminExt` in pacto-gov — factory, `addressOwner`, or Hats tree owner.

#### 4.3.1 `SquadSponsorExt` clone — address primitive

One clone per squad; inherits `SquadSponsor` (pool + hats on same address).

**Implemented surface (see `SquadSponsorExt.sol`):**

- `initialize(squadId, paymaster, factory, addressOwner)`
- `setPermittedAddress` / `transferAddressOwner` — while `topHatId == 0`
- `postInitialize(topHatId, registry, customHats)` — `HatWireAuth`; calls `_wireHats` on **this** clone; clears `addressOwner`
- `_isEligible`: `permittedAddress` pre-wiring; hat rules post-wiring (`super._isEligible`)

**Address updates:** App squad inbox → **`addressOwner`** calls **`setPermittedAddress`**. Not duplicated in pacto-gov.

#### 4.3.2 `SquadSponsor` clone — hats (PactoGov or custom tree)

Hat-first path via `createSquadSponsor`, or inherited by Ext after `postInitialize`.

**Implemented surface (see `SquadSponsor.sol`):**

- `initialize(squadId, paymaster, factory, topHatId, registry, customEligibleHats)`
- `_isEligible`: registry crew + captain hats when `registry != address(0)`; plus `customEligibleHats`

#### 4.3.3 `addressOwner` role (early bird)

**Who:** **`msg.sender` of first deposit** when `Factory.createSquad` runs (D16).

**What owner CAN do:**

| Action | Purpose |
|--------|---------|
| `setPermittedAddress(member, true/false)` | Sync squad inbox EVM shares → sponsor eligibility (pre-hat wiring) |
| `postInitialize(...)` | **Fallback** if `NavePirataFactory` fails to wire hats — same auth as factory path |
| `transferAddressOwner(newOwner)` | Hand off inbox/roster duty (D17) |

**What owner CANNOT do:**

| Forbidden | Why |
|-----------|-----|
| Withdraw others’ deposits | **`sponsorShares`** mapping — only own share withdrawable |
| Spend pool gas directly | Only paymaster deducts via validated UserOps |
| Change pro-rata accounting | Base logic is fixed |
| Override hat eligibility after `postInitialize` | Hat clone takes over; address list ignored for gas |

**So yes:** depositors are protected by **`sponsorShares`**; **`addressOwner`** is purely **eligibility admin** for the address primitive + **`postInitialize` backup** — not a pool custodian.

#### 4.3.4 `transferAddressOwner` (Q5 explained)

**Question was:** Can `addressOwner` change over time?

**v1 default (D17):** **Yes** — `transferAddressOwner(newOwner)` callable only by current owner.

**Why it matters:**

- First depositor (“early bird”) may not remain the person managing squad inbox long-term.
- After gov deploy, captain might need to approve EVM shares on-chain — transfer owner to captain EOA or ops Safe **without moving pool funds**.
- Transfer affects **who can call `setPermittedAddress`** only; it does **not** affect **`sponsorShares`** or hat eligibility after wiring.

**If owner is lost:** pre-hat squads cannot update address list until factory/owner/Hats-owner runs `postInitialize` or ops intervenes — document recovery in app (same class of problem as lost admin keys elsewhere).

#### 4.3.5 Summary

| Artifact | Scope | Eligibility |
|----------|-------|-------------|
| `SquadSponsorFactory` | Chain singleton | Creates clones; CREATE2 deploy with paymaster |
| Sponsor clone (`Ext` or `Sponsor`) | Per squad | Pool + eligibility (address and/or hats) |
| `PactoSponsorPaymaster` | Chain singleton | ERC-4337 validation + `spendGas` billing |

### 4.5 Optional: `SquadAddressResolver` library (pure / internal)

When registry is configured and `topHatId` is linked, pure helpers for **optional** defense-in-depth:

- `squadTargets(Deployment d, UpgradeRecord[] upgrades) → address[]`
- `isSquadTarget(address target, Deployment d, UpgradeRecord[] upgrades)`

**Not** a selector allowlist — the app defines which calls are built. This library only answers “does this target belong to this squad’s deployment?”

---

## 5. Optional pacto-gov address resolution

Use this section when registry is wired. It supports optional paymaster target checks — **not** sponsorship eligibility.

### 5.1 Registry (optional)

`INavePirataRegistry` (`pacto-gov`):

- `deployment(uint256 topHatId) → Deployment`
- `upgradeAt(topHatId, i) → UpgradeRecord` (`newClone` replaces old role addresses)

When linked, resolve latest clone addresses on validation so upgraded role hats still match squad contracts. No manual pool update on upgrade.

### 5.2 Typical app-UX targets (reference for app + relay, not on-chain gate)

These are the governance surfaces the Pacto app exposes today. Sponsorship follows the app, not a duplicated on-chain selector table:

| Contract | Example UX actions |
|----------|-------------------|
| `TreasuryAuthority` | `propose`, `crewVote`, `captainVote`, `execute` |
| `MutinyModule` | `startMutinyTo*`, `castVote`, `executeMutiny`, `captainResign` |
| `Quartermaster` | crew add/remove |
| `SquadAdmin` | role create/delete, executor enable/disable |
| `NavePirataFactory` | `deployNavePirata` (when **`PactoAdmin`** permits) |
| Safe factory / setup | Safe deploy flows (when **`PactoAdmin`** permits) |

**Exclude from app UX (therefore never sponsored):** `AssetRescuer` sweeps, raw transfers, arbitrary unlisted calls.

**Safe (v1 — locked: Path A):** Gnosis Safe is fundamental to governance (pause-captain, treasury). Squads enable Safe’s **ERC-4337 compatibility** (Safe 4337 module / supported Safe version per chain).

**Flow:**

1. Safe has 4337 module installed; Safe address is a valid **`userOp.sender`**.
2. App builds **ERC-4337 UserOp** whose `sender` is the **Safe** and `callData` is **`execTransaction(...)`** (or module batch).
3. Safe owners sign the UserOp per 4337 rules (threshold / owners).
4. Bundler → **`PactoSponsorPaymaster`** validates:
   - At least one validated signer is **eligible** (hat wearer or Ext permitted address)
   - Inner call targets are app-allowed (gov modules, treasury, etc.)
5. `postOp` → sponsor clone `spendGas`.

**Also sponsor:** module paths (QM/MM/TA) where **`msg.sender`** is member EOA when app uses direct module calls instead of Safe exec.

**Out of scope v1:** Path B (Safe SDK + external relay without 4337 sender), Path C (EOA-only workaround).

Pin Safe + 4337 module addresses per chain in `deployments/<chainId>/sponsor.json`. Reference: [Safe supported networks](https://docs.safe.global/advanced/smart-account-supported-networks).

### 5.3 Hat checks (optional)

Target contracts enforce `HatGated` via `IHats.isWearerOfHat(msg.sender, hatId)`. Paymaster may optionally pre-check wearers when registry is linked; **authorization remains on the target contract**.

---

## 6. Off-chain / app integration

### 6.1 Alchemy + ERC-4337 (v1)

1. **`PactoSponsorPaymaster`** (ERC-4337 verifying paymaster) staked on EntryPoint.
2. **Gas Manager** policy → paymaster address.
3. **Bundler** `eth_sendUserOperation` — this is the “relayer” (Alchemy submits UserOps; members still sign).
4. App flow:
   - Resolve `squadId`, chainId, eligibility path (Ext vs Base)
   - **Low balance:** app-side alert only — no on-chain threshold
   - EOA: 7702 delegation if needed, then ERC-4337 UserOp + paymaster
   - Contract wallet / **Safe (4337 module):** ERC-4337 UserOp with `sender` = account / Safe (§5.2)
   - Sign → bundler → paymaster validates → sponsor clone pays gas via `spendGas`

Docs:

- [Alchemy AA Overview](https://docs.alchemy.com/docs/account-abstraction-overview)
- [Gas Manager policies](https://docs.alchemy.com/docs/gas-manager-services)

### 6.2 Pacto app data model

Per squad per chain:

```ts
type SquadSponsorState = {
  squadId: `0x${string}`;
  sponsorAddress: Address;      // registered clone (Ext or Sponsor variant)
  hatsWired: boolean;           // Ext: topHatId != 0
  topHatId?: bigint;
  eligibilitySource: 'ADDRESS' | 'HATS';
  permittedMembers?: Address[]; // Ext only, when !hatsWired
  paymasterAddress: Address;
  balanceWei: bigint;
  sponsors: { address: Address; shares: bigint; withdrawableWei: bigint }[];
};
```

### 6.4 Squad inbox — EVM share (app; out of scope for this repo)

1. EVM share moves to **squad inbox** (from DMs).
2. App calls **`SquadSponsorExt.setPermittedAddress`** via **`addressOwner`** for that squad.
3. **Crew hat mint prompts** — deferred (not v1); captain-controlled minting off sponsor path for now.

### 6.3 Error UX (fallback)

Prefer sponsorship “just works.” On failure:

- `INSUFFICIENT_SQUAD_GAS` — pool empty
- `NOT_ELIGIBLE` — not on Ext address list (pre-wiring) or not hat wearer (post-wiring)
- `POLICY_REJECTED` — call not accepted by relay / failed on-chain sanity check
- `DELEGATION_REQUIRED` — EOA needs 7702 setup (one-tap retry)

Optional: deep link for sponsor to `deposit(squadId)` with suggested amount.

---

## 7. Security considerations

| Risk | Mitigation |
|------|------------|
| Unauthorized pool spend | `isEligible` via Ext or Base on every ERC-4337 UserOp |
| Pre-gov address spam | `setPermittedAddress` gated by `addressOwner`; app gates inbox share |
| Unauthorized action (deploy, admin, etc.) | **`PactoAdmin`** + target contracts — sponsor does not enforce; tx reverts before gas matters |
| Paymaster drains squad pool on arbitrary calls | Spend permission + app relay policy; reject drain patterns (deferred on-chain allowlists) |
| Reentrancy from spend | CEI; `spendGas` nonReentrant |
| Sponsor share inflation | `mulDiv` on deposit; no donation attack without ETH |
| Unmapped ETH lock | `saviourWithdraw` + explicit `unallocated` accounting |
| Malicious 7702 implementation | Paymaster allowlists `ALLOWED_7702_IMPLEMENTATION`; app must not sign arbitrary delegation |
| Cross-squad drain | `squadId` in paymaster data must match linked `topHatId`; no spend without balance on that id |
| Upgrade clone swap | Read `upgradeAt` on every validation (cache in indexer off-chain, verify on-chain) |

**Audits:** Before mainnet, internal review + external audit recommended for paymaster + sponsor clones.

---

## 8. pacto-gov integration

See **[`PACTO_GOV_FOLLOWUPS.md`](./PACTO_GOV_FOLLOWUPS.md)** for required pacto-gov PRs.

Summary: **`SquadSponsorExt` pre-deployed** → squad uses address mode → gov or manual **`postInitialize`** wires hats on **same clone** → hat eligibility overrides addresses.

---

## 9. Repository layout (target)

```
pacto-squad-sponsor/
├── docs/
│   ├── TECH_SPEC.md
│   └── PACTO_GOV_FOLLOWUPS.md
├── src/
│   ├── interfaces/          # ISquadSponsor*, IPactoSponsorPaymaster, …
│   └── contracts/
│       ├── abstracts/SquadSponsorBase.sol
│       ├── SquadSponsorFactory.sol
│       ├── SquadSponsor.sol
│       ├── SquadSponsorExt.sol
│       ├── PactoSponsorPaymaster.sol
│       └── utils/
├── script/
│   ├── Constants.sol
│   ├── SponsorDeploy.sol    # shared deploy (script + IntegrationBase)
│   ├── SponsorDeployLib.sol # CREATE2 factory ↔ paymaster
│   └── Deploy.sol
├── test/
│   ├── unit/                # `--match-contract Unit`
│   └── integration/         # `IntegrationBase`, `E2E*` (`--match-contract E2E`)
├── remappings.txt             # pacto-gov interfaces as submodule @pacto-gov/...
└── deployments/<chainId>/sponsor.json
```

**Dependencies:**

- OpenZeppelin Contracts
- `account-abstraction` (eth-infinitism)
- **pacto-gov** (submodule, optional): `INavePirataRegistry` for fork tests and `SquadAddressResolver` — pin commit tag; **not** a runtime dependency for gov-free deployment

Remove boilerplate `Greeter` when implementing.

---

## 10. Executable implementation plan

### Phase 0 — Repo hygiene

- ✅ Remove `Greeter` sample; align `foundry.toml` with pacto-gov (`solc 0.8.30`, `lintspec`, CI).
- ✅ Add `pacto-gov` dependency via `pnpm` + `remappings.txt` (read-only interfaces; no `lib/` submodule).
- ✅ Add `script/Constants.sol` for public chain + deployment addresses; `.env.example` for **private keys/RPC only**

### Phase 1 — Factory + sponsor clones

- ✅ `SquadSponsorFactory`: `createSquadSponsorExt`, `createSquadSponsor`, `createWarGameSponsorExt`; configured `addressOwner` on Ext; registry + master copies.
- ✅ `SquadSponsorBase`: pro-rata deposit/withdraw, `spendGas`, shared init.
- ✅ `SquadSponsorExt`: `setPermittedAddress`, `transferAddressOwner`, `postInitialize` (hats on same clone).

### Phase 2 — SquadSponsor hat path + ERC-4337 paymaster

- ✅ `SquadSponsor`: PactoGov (crew + captain) + custom eligible hat list.
- ✅ `PactoSponsorPaymaster`: registry check, `spendablePoolWei` headroom (no `BALANCE`), `paymasterAndData` v1 decode, EOA `sender == member` binding.
- ✅ `SquadSponsorFactory` FCFS paymaster stake: `addPaymasterStake` / `unlockPaymasterStake` / `withdrawPaymasterStake` / `withdrawPaymasterDeposit` (staker controls `withdrawTo`).
- ✅ `SquadSponsorBase.spendablePoolWei` storage accounting on deposit / withdraw / spendGas.
- ✅ Unit tests: pool accounting; Ext → `postInitialize` → hats; paymaster validation; war-game per-round clones (**124** unit tests).
- ✅ **Integration scaffold:** `IntegrationBase` + `SponsorDeploy` (same CREATE2 path as `script/Deploy.sol`); `E2E*` smoke on mainnet fork (`DEFAULT_MAINNET_FORK_BLOCK = 22_900_000`).
- [ ] **Integration / e2e:** sponsored UserOp through EntryPoint on fork; Safe Path A signer validation.

### Phase 3 — Mainnet + Arbitrum

- [ ] Deploy Factory + Paymaster on `1` and `42161`; commit `deployments/<chainId>/sponsor.json`
- [ ] Pin EntryPoint + Hats + Safe 4337 module addresses per chain (§10.1)
- [ ] Audit checklist before mainnet

### Phase 4 — pacto-gov factory (parallel / after mainnet deploy)

- [ ] Items in [`PACTO_GOV_FOLLOWUPS.md`](./PACTO_GOV_FOLLOWUPS.md) — not blocking Phases 0–2 in this repo

---

### 10.1 Implementation appendix (for executing agent)

**Confidence:** Phases **0–2** core contracts and unit tests are complete. Deploy scripts (`SponsorDeploy`, CREATE2 factory ↔ paymaster) ready; broadcast is Phase 3. Phase 4 needs pacto-gov PR.

#### Dependencies (Phase 0)

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.1.0
forge install eth-infinitism/account-abstraction@v0.7.0
forge install foundry-rs/forge-std
git submodule add https://github.com/covenant-gov/pacto-gov lib/pacto-gov  # interfaces + fork tests
```

Remappings to add: `@openzeppelin/`, `@account-abstraction/`, `@pacto-gov/`.

#### Clone pattern

- Use OpenZeppelin **`Clones` (EIP-1167)** minimal proxies.
- **`SquadSponsorFactory`** holds `sponsorImplementation` + `extImplementation`; **`createSquadSponsorExt`** or **`createSquadSponsor`** clones one sponsor per `squadId`; **`createWarGameSponsorExt`** clones an additional Ext per parent round (`cloneDeterministic`); optional ETH on create → `depositFor`.
- Ext **`postInitialize`** wires hats on **that** clone (no second deploy for the same `squadId`). War-game replay creates a new round clone instead of rewiring.

#### `paymasterAndData` layout (v1 — as implemented)

```
// After ERC-4337 paymaster header (52 bytes):
uint8 version = 1;
bytes32 squadId;
address sponsor;   // registered clone for squadId
address member;    // eligibility subject
```

Paymaster validates `sponsor` against **`SquadSponsorFactory.squads(squadId)`** (anti-spoof).

#### Chain constants (verify before mainnet deploy)

Canonical source: **`script/Constants.sol`** (`Constants.getConfig(chainId)`). Do not duplicate in `.env`.

| Chain | chainId | EntryPoint v0.7 | Hats v1 |
|-------|---------|-----------------|---------|
| Sepolia | 11155111 | in Constants | in Constants |
| Mainnet | 1 | in Constants | in Constants |
| Arbitrum One | 42161 | in Constants | in Constants |

**Safe 4337 (Path A):** Pin **Safe4337Module** / compatible module address per chain from [Safe docs](https://docs.safe.global/) at deploy time; store in `deployments/<chainId>/sponsor.json`. Paymaster validates UserOp via module’s expected `validateUserOp` / owner signature layout — mirror Safe’s reference integration tests.

#### Configuration split

| Private (`.env` only) | Public (`script/Constants.sol`) |
|------------------------|----------------------------------|
| `MAINNET_RPC`, `SEPOLIA_RPC`, `ARBITRUM_RPC` | `entryPoint`, `HATS_PROTOCOL_V1`, `DEFAULT_MAINNET_FORK_BLOCK` |
| `ETHERSCAN_API_KEY`, `ALCHEMY_API_KEY` | `navePirataRegistry`, `safe4337Module` |
| `*_DEPLOYER_NAME` (keystore labels) | `squadSponsorFactory`, `paymaster` after deploy |
| | `mainnetForkBlock` for integration tests |

After deploy, update **`Constants.sol`** (and optionally `deployments/<chainId>/sponsor.json` for app consumption).

#### `.env.example` (Phase 0)

Private keys and RPC URLs only — see repo `.env.example`.

#### External resources that de-risk (nice-to-have, not blocking Phase 0–1)

| Resource | Why |
|----------|-----|
| **`SquadAdminExt.sol`** from pacto-gov (submodule) | Copy `postInitialize` auth modifiers exactly |
| **`INavePirataRegistry.sol`** | `SquadSponsor.isEligible` PactoGov path |
| Published pacto-gov **mainnet** `deployments/` (or pinned mainnet addresses) | Integration fork tests (D19) |

#### Explicitly deferred (do not implement in first PR)

- Crew hat mint sponsorship
- pacto-gov factory `postInitialize` call (Phase 4)
- On-chain low-balance alerts

---

## 11. Testing requirements

| Test type | Environment | Requirement |
|-----------|-------------|-------------|
| **Unit** | Local (no fork) | Pool accounting, eligibility, paymaster validation (`--match-contract Unit`) |
| **Integration / e2e** | **Mainnet fork** (`MAINNET_RPC`, `IntegrationBase`, block `22_900_000`) | Deploy smoke + Ext fixtures; **TODO:** full UserOp through EntryPoint |
| **Fuzz** | Local | deposit/withdraw/spend sequences preserve `sum(withdrawable) <= balance` |
| **Gas** | Local | Cap tables enforced — oversized UserOp rejected |
| **Frontend live** | **Sepolia deploy** (Phase 3) | App + Alchemy bundler against deployed contracts — **not** Foundry fork tests |

CI integration job uses `MAINNET_RPC` secret for fork tests. `SEPOLIA_RPC` is for deploy scripts and manual frontend QA only.

---

## 12. Open decisions (minimal — default if unanswered)

| ID | Question | **Default for v1** |
|----|----------|---------------------|
| Q1 | `postInitialize` auth | Factory, **`addressOwner`**, or Hats owner — match `SquadAdminExt` |
| Q2 | `addressOwner` bootstrap | **First depositor** on `createSquad` (D16) |
| Q3 | Custom Hats without PactoGov | **`postInitialize`** — same norm as **`PactoAdmin`** (locked) |
| Q4 | Per-squad clone isolation | **Yes** — one sponsor clone per squad (D1) |
| Q5 | `addressOwner` transfer | **Transferable** by current owner (D17) |
| Q6 | Safe sponsorship | **Path A locked** — Safe as ERC-4337 smart account (D18) |
| Q7 | Optional address revoke | Optional — not critical v1 |
| Q8 | Chains | Mainnet, Sepolia, Arbitrum One |

---

## 13. Reference links

| Topic | URL |
|-------|-----|
| EIP-7702 | https://eips.ethereum.org/EIPS/eip-7702 |
| EIP-4337 | https://eips.ethereum.org/EIPS/eip-4337 |
| ERC-4337 EntryPoint v0.7 | https://github.com/eth-infinitism/account-abstraction |
| Hats supported chains | https://docs.hatsprotocol.xyz/using-hats/hats-protocol-supported-chains |
| Safe deployments | https://docs.safe.global/advanced/smart-account-supported-networks |
| pacto-gov registry | `src/interfaces/factory/INavePirataRegistry.sol` |
| Alchemy AA | https://docs.alchemy.com/docs/account-abstraction-overview |
| Pectra / 7702 rollout | Check Ethereum Foundation Pectra notes per network before enabling on mainnet |

---

## 14. Agent handoff checklist

Before marking v1 complete:

1. `forge test` green in pacto-squad-sponsor
2. `lintspec` / `forge fmt` clean
3. README updated: collective model, deposit/withdraw, **permissions vs gas**
4. Explicit note: factory co-deploy is optional PR in pacto-gov — sponsor repo stands alone

---

*End of spec.*
