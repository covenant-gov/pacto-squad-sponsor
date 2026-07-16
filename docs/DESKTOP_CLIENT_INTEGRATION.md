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
| Gas | Will the squad pool pay for this UserOp? | `PactoSponsorPaymaster` + squad clone |

A UserOp is sponsored when **all** of the following hold:

1. `paymasterAndData` encodes version `1`, the correct `squadId`, the **factory-registered** sponsor clone, and a non-zero `member`.
2. Pool ETH balance ≥ `maxCost × 115%` (integer division; see §5).
3. `ISquadSponsorBase(sponsor).isEligible(member)` is true:
   - **Ext (pre-hat wiring):** `member` is on the Ext permit list.
   - **Hat path (hat-first clone or Ext after `postInitialize`):** `member` wears captain or crew hat from `NavePirataRegistry.deployment(topHatId)`, or a configured `customEligibleHats` hat.
4. Member binding:
   - **EOA sender** (`userOp.sender.code.length == 0`): `sender == member` (else hard revert `SS_InvalidMemberBinding`).
   - **Smart-account sender** (code present, including EIP-7702-delegated EOAs): binding skipped; eligibility is evaluated on `member` only. Safe signer → `member` mapping is **deferred** (not enforced on-chain yet).

Hat wearers with **0 native ETH** are exactly the clients this path serves: gas comes from the squad pool via `spendGas` in `postOp`, not from the roster key balance.

---

## 2. Supported v1 path (7702 vs bare EOA)

### Decision (desktop v1)

| Path | Status | Notes |
|------|--------|--------|
| **ERC-4337 UserOp + `PactoSponsorPaymaster`** | **Supported** | Required for all sponsored gov writes. |
| **EOA + EIP-7702 delegation** then UserOp | **Supported transport for roster EOAs** | Bare EOAs cannot implement `validateUserOp`. App must set-code (7702) to an ERC-4337 account implementation, then submit a UserOp with `sender == member == roster EVM`. |
| **ERC-4337 smart account as `sender`** (e.g. Safe + 4337 module) | **Supported** | Put the eligible hat wearer / Ext member in `PaymasterData.member`. Signer→member proof is deferred. |
| Bare EOA as UserOp `sender` without 7702 / account code | **Not executable** | EntryPoint cannot validate the op. |
| Legacy `eth_sendTransaction` from roster key | **Not sponsored** | Current app failure mode (`insufficient funds`). |

**Paymaster note on 7702:** After successful 7702 set-code, `sender.code.length > 0`, so the paymaster treats the address as a **smart-account sender** (skips `sender == member`). Until a `walletImplementation` allowlist lands (see TECH_SPEC D13 / deferred items), clients **must** still set `member` to the eligible roster address and must not rely on paymaster-side 7702 allowlisting.

**Safe 4337 module:** Not pinned in this repo yet (`safe4337Module` is `address(0)` in `Constants.sol`). Pin per chain from Safe docs when Path A is wired in the app.

---

## 3. Addresses (Sepolia)

Source of truth for deployed Sepolia system contracts: [`deployments/11155111/full-system.json`](../deployments/11155111/full-system.json).  
Cross-link these into `pacto-app` `pacto-protocol-addresses.json` (same chain id `11155111`).

| Role | Address |
|------|---------|
| EntryPoint v0.7 | `0x0000000071727De22E5E9d8BAf0edAc6f37da032` |
| `SquadSponsorFactory` | `0x032e84cff3b32c221f8F93e4839Fa5715638ae08` |
| `PactoSponsorPaymaster` | `0xF7f557a9443671EB0f5a3F1b233Ac44A9eDa24B8` |
| Sponsor implementation | `0x712b49AC221Df7b445eCDd25B681c3BD92Fcb2E8` |
| Ext implementation | `0x143c0a014CBF9Bfab5aFF886A004B8b393Bc878a` |
| `NavePirataRegistry` | `0x45127C1c92741C0dA38e1A73fbb97a8a2C46770f` |
| Hats Protocol v1 | `0x3bc1A0Ad72417f2d411118085256fC53CBdDd137` |

**Mainnet / Arbitrum:** EntryPoint and Hats are the same canonical addresses; factory/paymaster are not deployed in-repo yet (`address(0)` in `script/Constants.sol`).

Per-squad clone addresses come from factory create / app deploy flow — look up with `factory.squads(squadId)` or `factory.squadIdBySponsor(sponsor)`.

---

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
3. `sponsor.balance >= maxCost * 11500 / 10000` → else soft-fail `validationData = 1` (`SIG_VALIDATION_FAILED`).
4. Eligibility / binding → soft-fail `1` or hard revert `SS_InvalidMemberBinding` (EOA mismatch).
5. Success: `context = abi.encode(sponsor)`, `validationData = 0`.
6. On `postOp` with `opSucceeded` only: `sponsor.spendGas(actualGasCost)` (pool decreases by exactly `actualGasCost`).

The paymaster does **not** inspect `userOp.callData`, enforce calldata allowlists, or cap gas classes (deferred).

---

## 5. Documented EOA-sponsored external call flow

**Scenario:** Captain roster EVM has captain hat, **0 ETH**, squad sponsor pool funded. App must call `Quartermaster.bootstrapCrew(address[])` without a plain EOA broadcast.

### Steps

1. Resolve `squadId` and registered `sponsor` (factory registry). Confirm `sponsor.isEligible(captainEoa)`.
2. Ensure pool headroom: `sponsor.balance >= ceilEstimate(maxCost) * 115 / 100` (see §7).
3. If the roster key still has empty code: submit **EIP-7702 authorization** delegating to the app’s pinned ERC-4337 account implementation (one-time / as needed).
4. Build a packed UserOperation:
   - `sender` = captain roster EVM (after 7702, this is the account that validates the UserOp).
   - `callData` = account `execute(quartermaster, 0, bootstrapCrewCalldata)` (or Safe equivalent).
   - `paymasterAndData` = header + `abi.encode(1, squadId, sponsor, captainEoa)` with `member = captainEoa`.
   - Sign per the account implementation / 7702 rules (not the paymaster).
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
| `SS_InvalidMemberBinding(sender, member)` | Hard revert | EOA `sender ≠ member` | Set both to the roster EVM (eligibility subject). |
| `validationData == 1` (`SIG_VALIDATION_FAILED`) | Soft fail | Ineligible member, `member == 0`, or pool &lt; `maxCost × 115%` | Check `isEligible(member)`; fund pool; lower gas / `maxCost`. |
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

| Who | Can withdraw? |
|-----|----------------|
| Address with `sponsorShares[addr] > 0` | **Yes** — burns all of **their** shares; receives pro-rata of **current** pool balance |
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
| 7702 implementation allowlist | **Deferred** — pin trusted delegate in the app. |
| Calldata allowlists | **Deferred** — app must only build permitted gov module calls. |

---

## 10. Client checklist (`pacto-app`)

1. Stop using `send_transaction` for hat-gated gov writes when the roster key has insufficient ETH and a squad sponsor exists.
2. Load `squadId`, `sponsor`, EntryPoint, paymaster from protocol addresses + factory.
3. Encode `paymasterAndData` (TS helper or golden vectors).
4. Build UserOp `callData` via account `execute` → gov module ABI.
5. Ensure 7702 delegation (EOA) or Safe 4337 path (smart account).
6. Submit UserOp; map paymaster errors in §6 to UX copy.
7. Consume [`fixtures/client-integration/paymasterAndData.vectors.json`](../fixtures/client-integration/paymasterAndData.vectors.json) in Rust/TS unit tests (no mainnet fork required).
