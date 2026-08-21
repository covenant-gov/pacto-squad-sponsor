# Desktop client integration — ERC-4337 sponsored squad governance

**Audience:** `pacto-app` (and any client) routing hat-gated governance writes through `PactoSponsorPaymaster`.  
**Companion app issue:** [covenant-gov/pacto-app#87](https://github.com/covenant-gov/pacto-app/issues/87)  
**Spec issue:** [covenant-gov/pacto-squad-sponsor#5](https://github.com/covenant-gov/pacto-squad-sponsor/issues/5)  
**Canonical product/security spec:** [`TECH_SPEC.md`](./TECH_SPEC.md)  
**Golden vectors:** [`fixtures/client-integration/paymasterAndData.vectors.json`](../fixtures/client-integration/paymasterAndData.vectors.json)  
**TS encoder:** [`client/encodePaymasterAndData.ts`](../client/encodePaymasterAndData.ts)

---

## 1. When sponsorship applies

Sponsorship pays **gas only**. Action permission stays in `pacto-gov` (`PactoAdmin` / target modules such as `Quartermaster`).

| Layer | Question | Contract |
|-------|----------|----------|
| Permission | May this address call `bootstrapCrew` / etc.? | pacto-gov |
| Gas | Will the squad pool pay for this UserOp? | `PactoSponsorPaymaster` + `SquadSponsorPool` + eligibility clone |

A UserOp is sponsored when **all** of the following hold:

1. `paymasterAndData` encodes version `1`, the correct `squadId`, the **factory-registered** sponsor clone, and a non-zero `member`.
2. The clone occupies `pool.defacto()` or `pool.wargame()` (`pool = sponsor.pool()`). Else hard revert `SS_SponsorNotInPoolSlot`.
3. `pool.spendablePoolWei() >= maxCost × 115%` (integer division; see §7). Storage-backed — **not** `address(sponsor).balance` (ERC-7562 bans `BALANCE` during paymaster validation unless the paymaster is staked). Clones forward `spendablePoolWei()` to the pool.
4. `ISquadSponsorBase(sponsor).isEligible(member)` is true:
   - **Ext (pre-hat wiring):** `member` is on the Ext permit list.
   - **Hat path (hat-first clone or Ext after `postInitialize`):** `member` wears captain or crew hat from `NavePirataRegistry.deployment(topHatId)`, or a configured `customEligibleHats` hat.
5. Member binding:
   - **EOA sender** (`userOp.sender.code.length == 0`): `sender == member` (else hard revert `SS_InvalidMemberBinding`).
   - **EIP-7702 sender** (23-byte stub `0xef0100 || impl`): `sender == member`, and `impl` must equal the paymaster’s immutable `ALLOWED_7702_IMPLEMENTATION` (else `SS_Invalid7702Implementation`). Pin that address from [`deployments/<chainId>/eip7702-account.json`](../deployments/11155111/eip7702-account.json).
   - **Other smart-account sender** (Safe, etc.): binding skipped; eligibility is evaluated on `member` only. Safe signer → `member` mapping is **deferred** (not enforced on-chain yet).

Hat wearers with **0 native ETH** are exactly the clients this path serves: gas comes from the squad pool via `spendGas` in `postOp`, not from the roster key balance.

---

## 2. Supported v1 path (7702 vs bare EOA)

### Decision (desktop v1)

| Path | Status | Notes |
|------|--------|--------|
| **ERC-4337 UserOp + `PactoSponsorPaymaster`** | **Supported** | Required for all sponsored gov writes. |
| **EOA + EIP-7702 → `PactoSimple7702Account`** then UserOp | **Supported transport for roster EOAs** | Bare EOAs cannot implement `validateUserOp`. App set-codes to the Pacto-owned impl in `eip7702-account.json`, then submits a UserOp with `sender == member == roster EVM`. |
| **ERC-4337 smart account as `sender`** (e.g. Safe + 4337 module) | **Supported** | Put the eligible hat wearer / Ext member in `PaymasterData.member`. Signer→member proof is deferred. |
| Bare EOA as UserOp `sender` without 7702 / account code | **Not executable** | EntryPoint cannot validate the op. |
| Legacy `eth_sendTransaction` from roster key | **Not sponsored** | Current app failure mode (`insufficient funds`). |

**Paymaster note on 7702:** After successful 7702 set-code, the sender has designated code `0xef0100 || PactoSimple7702Account`. The paymaster **still** requires `sender == member` and that the delegated implementation matches `ALLOWED_7702_IMPLEMENTATION` (wired at factory/paymaster deploy via `PACTO_7702_ACCOUNT`). Other contract wallets (non-7702) keep the deferred Safe-style path.

**Client signing contract (PactoSimple7702Account):**

| Concern | Value |
|---------|--------|
| Set-code target | `pactoSimple7702Account` in [`eip7702-account.json`](../deployments/11155111/eip7702-account.json) |
| EntryPoint | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| Nonce | `entryPoint.getNonce(sender, key=0)` |
| Signature | Raw 65-byte ECDSA over EntryPoint `getUserOpHash` (Electrum `v` 27/28) — **not** `personal_sign`, **not** Alchemy MAv2 `0xFF\|\|0x00\|\|…` packing |
| Calldata | `execute(address,uint256,bytes)` wrapping the gov module call |

**Safe 4337 module:** Not pinned in this repo yet (`safe4337Module` is `address(0)` in `Constants.sol`). Pin per chain from Safe docs when Path A is wired in the app.

---

## 3. Addresses (Sepolia)

Source of truth for deployed Sepolia **sponsor** contracts: [`deployments/11155111/full-system.json`](../deployments/11155111/full-system.json).  
Source of truth for the **EIP-7702 account** implementation: [`deployments/11155111/eip7702-account.json`](../deployments/11155111/eip7702-account.json) (publish after `pnpm deploy:7702:sepolia`).  
Cross-link these into `pacto-app` `pacto-protocol-addresses.json` (same chain id `11155111`), including `erc4337.accountImplementation`.

| Role | Address |
|------|---------|
| EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| `PactoSimple7702Account` | see `eip7702-account.json` (deploy before full-system cutover) |
| `SquadSponsorFactory` | see `full-system.json` |
| `PactoSponsorPaymaster` | see `full-system.json` |
| Sponsor / Ext implementations | see `full-system.json` |
| `NavePirataRegistry` | `0x45127C1c92741C0dA38e1A73fbb97a8a2C46770f` |
| Hats Protocol v1 | `0x3bc1A0Ad72417f2d411118085256fC53CBdDd137` |

**Deploy order (greenfield):** (1) `pnpm deploy:7702:sepolia` → commit `eip7702-account.json`; (2) `pnpm deploy:sepolia` — allowlist resolves from that artifact (or non-zero `PACTO_7702_ACCOUNT`). Do not broadcast a full-system deploy with a zero allowlist; scripts revert on live chains.

**Paymaster fund (live top-up):** Greenfield `pnpm deploy:sepolia` does **not** fund EntryPoint deposit or FCFS stake. For an already-deployed factory/paymaster, run `pnpm fund:paymaster:sepolia` (simulate: `pnpm simulate-fund:paymaster:sepolia`): reads `full-system.json`, calls `paymaster.deposit` + `factory.addPaymasterStake`, does **not** redeploy or rewrite the artifact. Same env knobs as cutover: `PAYMASTER_EP_DEPOSIT_WEI`, `PAYMASTER_STAKE_WEI`, `PAYMASTER_UNSTAKE_DELAY_SEC` (defaults 0.1 ETH / 0.1 ETH / 172800). Occupied stake slot reverts `SS_StakeSlotOccupied` unless the broadcaster already holds it (top-up). Prefer this over ad-hoc `cast send` for Core ops.

**Paymaster cutover (wrong / zero allowlist):** If an existing factory/paymaster was deployed with `ALLOWED_7702_IMPLEMENTATION == address(0)`, that immutable cannot be patched. Run `pnpm cutover:paymaster:sepolia` (simulate: `pnpm simulate-cutover:paymaster:sepolia`): one forge broadcast redeploys factory+paymaster against the existing `PactoSimple7702Account` (does **not** redeploy 7702), asserts allowlist wiring, funds EntryPoint deposit + FCFS `addPaymasterStake`, and writes `full-system.json`. Optional env: `PAYMASTER_EP_DEPOSIT_WEI`, `PAYMASTER_STAKE_WEI`, `PAYMASTER_UNSTAKE_DELAY_SEC` (defaults 0.1 ETH / 0.1 ETH / 172800). After cutover, paste the new artifact into `pacto-app`’s address book (`pacto-protocol-addresses.json`); recreate squad sponsors (old clones stay wired to the dead paymaster). Do **not** use cutover to top up a healthy live paymaster.

**Mainnet / Arbitrum:** EntryPoint and Hats are the same canonical addresses; factory/paymaster / 7702 account are not deployed in-repo yet until you broadcast.

**Greenfield after stake/`spendablePoolWei` / 7702 allowlist redeploy:** A new factory creates a new paymaster. Existing Sepolia clones were initialized with the old paymaster and are **not** reusable — recreate squad sponsors after publishing new addresses. Prefer the JSON artifacts over any stale markdown tables.

Per-squad clone addresses come from factory create / app deploy flow — look up with `factory.squads(squadId)` or `factory.squadIdBySponsor(sponsor)`.

### War-game vs production `squadId`

| Channel | Registry `squadId` | Create |
|---------|--------------------|--------|
| `squad-dashboard` (real gov) | `parentSquadId = keccak256(parentId)` | `createSquadSponsorExt` / `createSquadSponsor` → pool `defacto` |
| `squad-wargame` (round N) | `factory.warGameSquadId(parentSquadId, N)` | `createWarGameSponsor` (hats-native) after `deployNavePirata`; Ext variant for Advanced address-list rounds → pool `wargame` |

War-game UserOps must encode the **round** `squadId` and that round’s clone. Using `parentSquadId` after production hats exist gates gas on the **production** hat tree (and only if that clone occupies `defacto`).

**War-game deploy sequence:**

1. If `factory.poolOf(parentSquadId) == 0`, the first create get-or-creates the primary pool. Do **not** occupy production `squads[parentSquadId]` for a throwaway game tree.
2. `deployNavePirata` (war-game stack) so the top hat is known.
3. `createWarGameSponsor(parentSquadId, topHatId, registry, customHats)` (optional `msg.value` funds the **parent pool**). Persist `round`, `gameSquadId`, `sponsor`. Factory sets `wargame`.
4. `squad-wargame` UserOps use `gameSquadId` + round sponsor; eligibility is this round’s captain/crew hats.
5. On replay: call `createWarGameSponsor` again (new round). Previous round stays registered but is unslotted; depositors withdraw from the **shared pool**, not the retired clone.

Ext-first (`createSquadSponsorExt` on production `parentSquadId`) is the live sponsor-before-hats path — not the war-game player path.

`createFreshPool` is an explicit escape hatch (new empty vault; old shares stay on the old pool).

---

## 3.1 Funding buckets (protocol ops vs squad)

| Bucket | Who funds | How |
|--------|-----------|-----|
| **Squad parent pool** | Squad members | `pool.deposit()` / create with value — reimburses paymaster via `spendGas` |
| **EntryPoint deposit** | Anyone (typically Core) | `paymaster.deposit{value:}()` — liquid gas float |
| **EntryPoint stake** | FCFS single staker via factory | `factory.addPaymasterStake` — bundler trust / ERC-7562 (Alchemy floor: **≥ 0.1 ETH**, delay **≥ 1 day**) |

Holding the FCFS stake slot (`factory.paymasterStaker()`) also controls:

- `unlockPaymasterStake` / `withdrawPaymasterStake` (clears slot)
- `withdrawPaymasterDeposit(to, amount)` → `paymaster.withdrawTo` (EP deposit exit)

Vacant slot → no deposit withdraw until someone stakes. No multi-contributor credit accounting (MVP).

Preferred ops path for Sepolia deposit + initial/top-up stake: `pnpm simulate-fund:paymaster:sepolia` then `pnpm fund:paymaster:sepolia` (see §3). Cast below is the manual fallback.

### Cast examples (Core ops — not end-user UI)

```bash
# Fund EP deposit (anyone)
cast send $PAYMASTER "deposit()" --value 0.05ether --rpc-url $SEPOLIA_RPC --account $OPS

# Claim FCFS stake slot (initial ≥ 0.1 ETH, delay ≥ 86400)
cast send $FACTORY "addPaymasterStake(uint32)" 86400 --value 0.1ether --rpc-url $SEPOLIA_RPC --account $OPS

# Top up (same staker only)
cast send $FACTORY "addPaymasterStake(uint32)" 86400 --value 0.01ether --rpc-url $SEPOLIA_RPC --account $OPS

# Unlock → wait delay → withdraw stake (clears slot)
cast send $FACTORY "unlockPaymasterStake()" --rpc-url $SEPOLIA_RPC --account $OPS
cast send $FACTORY "withdrawPaymasterStake(address)" $OPS_ADDR --rpc-url $SEPOLIA_RPC --account $OPS

# Withdraw EP deposit (current staker only)
cast send $FACTORY "withdrawPaymasterDeposit(address,uint256)" $OPS_ADDR 10000000000000000 --rpc-url $SEPOLIA_RPC --account $OPS
```

Without sufficient stake, bundlers may reject UserOps with `-32502` / banned opcode (`BALANCE`). After this codebase change, validation uses `spendablePoolWei()` instead of `BALANCE`, but stake is still required for normal bundler policy.

## 4. Building `paymasterAndData`

### 4.1 Layout

ERC-4337 v0.7 packed UserOp field (`UserOperationLib.PAYMASTER_DATA_OFFSET = 52`):

```
[0:20]   paymaster address
[20:36]  uint128 verificationGasLimit
[36:52]  uint128 postOpGasLimit
[52:]    abi.encode(uint8 version, bytes32 squadId, address sponsor, address member)
```

- `version` **must** be `PAYMASTER_DATA_VERSION` (`1`).
- Payload is standard Solidity ABI encoding (**128 bytes**; `uint8` left-padded to 32).
- Total length: **180 bytes**.

Reference builder (same as tests):

```solidity
bytes memory payload = abi.encode(uint8(1), squadId, sponsor, member);
bytes memory header = abi.encodePacked(paymaster, uint128(verificationGasLimit), uint128(postOpGasLimit));
bytes memory paymasterAndData = bytes.concat(header, payload);
```

Suggested gas limits for the header (not on-chain policy — sizing only): `verificationGasLimit = 100_000`, `postOpGasLimit = 50_000` (matches integration tests).

Use [`client/encodePaymasterAndData.ts`](../client/encodePaymasterAndData.ts) or the golden JSON vectors for off-chain encoding without a fork.

### 4.2 Validation order (operators)

1. Parse payload → wrong version **reverts** `SS_InvalidVersion`.
2. `factory.squads(squadId).sponsor == sponsor` → else **revert** `SS_CloneMismatch`.
3. `pool = sponsor.pool()`; `pool.defacto() == sponsor || pool.wargame() == sponsor` → else **revert** `SS_SponsorNotInPoolSlot`.
4. `pool.spendablePoolWei() >= maxCost * 11500 / 10000` → else soft-fail `validationData = 1` (`SIG_VALIDATION_FAILED`).
5. Eligibility / binding → soft-fail `1`, hard revert `SS_InvalidMemberBinding` (EOA / 7702 mismatch), or hard revert `SS_Invalid7702Implementation` (7702 stub not allowlisted).
6. Success: `context = abi.encode(pool)`, `validationData = 0`.
7. On `postOp` with `opSucceeded` only: `pool.spendGas(actualGasCost)` (pool decreases by exactly `actualGasCost`).

The paymaster does **not** inspect `userOp.callData`, enforce calldata allowlists, or cap gas classes (deferred).

---

## 5. Documented EOA-sponsored external call flow

**Scenario:** Captain roster EVM has captain hat, **0 ETH**, squad sponsor pool funded. App must call `Quartermaster.bootstrapCrew(address[])` without a plain EOA broadcast.

### Steps

1. Resolve `squadId` and registered `sponsor` (factory registry). Confirm `sponsor.isEligible(captainEoa)`.
2. Ensure pool headroom: `sponsor.spendablePoolWei() >= requiredBalance` (see §7).
3. If the roster key still has empty code: submit **EIP-7702 authorization** delegating to `PactoSimple7702Account` from `eip7702-account.json` (one-time / as needed).
4. Build a packed UserOperation:
   - `sender` = captain roster EVM (after 7702, this is the account that validates the UserOp).
   - `nonce` = `entryPoint.getNonce(sender, 0)`.
   - `callData` = account `execute(quartermaster, 0, bootstrapCrewCalldata)` (or Safe equivalent).
   - `paymasterAndData` = header + `abi.encode(1, squadId, sponsor, captainEoa)` with `member = captainEoa`.
   - Sign with **bare ECDSA** over EntryPoint `getUserOpHash` (not `personal_sign` / not MAv2 packing).
5. Submit via bundler (`eth_sendUserOperation`) to EntryPoint `0x0000000071727De22E5E9d8BAf0edAc6f37da032`.
6. On success, EntryPoint calls paymaster `postOp` → pool pays `actualGasCost`.

### Sample calldata (fixtures)

Selector `bootstrapCrew(address[])` = `0xc2af273a`.  
Account wrapper `execute(address,uint256,bytes)` = `0xb61d27f6`.

See vector `sample_external_call_bootstrapCrew` in the golden JSON for exact hex with placeholder addresses.

**Smart-account variant:** `sender` = Safe (or other 4337 account); `member` = eligible captain/crew EOA that wears the hat / is Ext-permitted. Do not set `member` to the Safe address unless that Safe itself is eligible.

---

## 6. Failure codes and remediation

| Symptom | Kind | Cause | Remediation |
|---------|------|-------|-------------|
| `SS_InvalidVersion(version)` | Hard revert | Payload version ≠ `1` | Rebuild `paymasterAndData` with version `1`. |
| `SS_CloneMismatch(squadId)` | Hard revert | `sponsor` ≠ `factory.squads(squadId).sponsor` | Refresh clone address from factory; never trust a client-supplied sponsor alone. |
| `SS_InvalidMemberBinding(sender, member)` | Hard revert | EOA / 7702 `sender ≠ member` | Set both to the roster EVM (eligibility subject). |
| `SS_Invalid7702Implementation(impl)` | Hard revert | 7702 stub delegates to a non-allowlisted impl | Set-code to `pactoSimple7702Account` from `eip7702-account.json`; redeploy factory if allowlist was wrong. |
| `validationData == 1` (`SIG_VALIDATION_FAILED`) | Soft fail | Ineligible member, `member == 0`, or `spendablePoolWei` &lt; `maxCost × 115%` | Check `isEligible(member)`; fund pool; lower gas / `maxCost`. |
| Bundler `-32502` / banned opcode | Bundler | Paymaster unstaked or legacy `BALANCE` validation | Stake via factory (≥0.1 ETH, ≥1 day); use redeployed paymaster with `spendablePoolWei`. |
| `SS_InsufficientBalance` | During `spendGas` | Pool drained between validation and postOp | Rare race; refund/retry after deposit. |
| `SS_NotPaymaster` | During `spendGas` | Non-paymaster called `spendGas` | Client bug — never call `spendGas` from the app. |
| `SS_NoShares` | `withdraw()` | Caller has no deposit shares | Only depositors withdraw (see §8). |
| Account / signature failures | EntryPoint / account | Bad UserOp sig, missing 7702, wrong nonce | Fix account path before paymaster debugging. |
| Legacy `SEND_FAILED` / `insufficient funds` | App | Plain EOA `send_transaction` with 0 ETH | Route through UserOp + paymaster (this doc). |

Soft failures return `validationData = 1` so bundler simulation can reject without a custom-error revert. Hard reverts abort simulation with the named error.

---

## 7. Pool balance heuristics

On-chain rule:

```text
requiredBalance = maxCost * 11500 / 10000   // Solidity integer division
// compared to sponsor.spendablePoolWei() (storage), not address(sponsor).balance
```

The paymaster does not define per-call gas caps. Size `maxCost` from bundler simulation / local gas estimate × max fee.

**Suggested minimum pool balances** (rough; re-estimate on Sepolia before shipping):

| Call class | Rough gas | At 2 gwei `maxFee` | Required pool (≥ 115%) |
|------------|-----------|--------------------|-------------------------|
| Small gov write | ~150k–250k | ~0.0003–0.0005 ETH | ~0.0006 ETH |
| `bootstrapCrew` (few addresses) | ~250k–400k | ~0.0005–0.0008 ETH | ~0.001 ETH |
| `bootstrapCrew` (larger batch) | ~600k–1M | ~0.0012–0.002 ETH | ~0.002–0.003 ETH |

App deploy flows often fund **0.001+ ETH** — enough for a small sponsored write at modest fees, but **not** enough if `maxCost` is set near 1 ETH (would need 1.15 ETH headroom). Prefer simulation-derived `maxCost`, not fixed large ceilings.

There is **no** on-chain calldata-size or batch-size limit for `bootstrapCrew` in the paymaster. Keep batches within account/`callGasLimit` budgets the bundler accepts.

---

## 8. `withdraw()` semantics (Treasury UI)

Call `withdraw` on the **parent pool** (`sponsor.pool()` / `factory.poolOf(parentSquadId)`), not on the eligibility clone.

| Who | Can withdraw? |
|-----|----------------|
| Address with `sponsorShares[addr] > 0` | **Yes** — burns all of **their** shares; receives pro-rata of **current** `spendablePoolWei` |
| Hat wearer / Ext-permitted member (no shares) | **No** — eligibility ≠ deposit rights |
| `addressOwner` (Ext admin) | **No** special withdraw power — cannot withdraw others’ deposits |

Gas spend reduces everyone’s withdrawable amount proportionally. Expose Treasury withdraw only when `withdrawable(account) > 0` (or `sponsorShares > 0`).

---

## 9. Contract gaps / deferred (desktop scope)

| Topic | Answer for desktop v1 |
|-------|------------------------|
| 7702 vs 4337 | Both: **4337 UserOp is mandatory**; **7702 is the EOA transport** so roster keys can be UserOp senders. Documented above. |
| Calldata / gas limits for `bootstrapCrew` | **None on-chain.** Client + bundler sizing only; maintain 115% pool headroom. |
| Safe signer → `member` | **Deferred** — do not assume paymaster checks Safe owners yet. |
| 7702 implementation allowlist | **Implemented** — paymaster requires EIP-7702 stubs to delegate to `ALLOWED_7702_IMPLEMENTATION` (`PactoSimple7702Account`). |
| Calldata allowlists | **Deferred** — app must only build permitted gov module calls. |

---

## 10. Client checklist (`pacto-app`)

1. Stop using `send_transaction` for hat-gated gov writes when the roster key has insufficient ETH and a squad sponsor exists.
2. Load `squadId`, `sponsor`, EntryPoint, paymaster from protocol addresses + factory. For `squad-wargame`, use `warGameSquadId(parentSquadId, round)` (not `keccak256(parentId)`).
3. Encode `paymasterAndData` (TS helper or golden vectors).
4. Build UserOp `callData` via account `execute` → gov module ABI.
5. Ensure 7702 delegation (EOA) or Safe 4337 path (smart account).
6. Submit UserOp; map paymaster errors in §6 to UX copy.
7. Consume [`fixtures/client-integration/paymasterAndData.vectors.json`](../fixtures/client-integration/paymasterAndData.vectors.json) in Rust/TS unit tests (no mainnet fork required).
