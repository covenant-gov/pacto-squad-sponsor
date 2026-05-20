# pacto-gov follow-ups (sponsor integration)

Changes required in **[covenant-gov/pacto-gov](https://github.com/covenant-gov/pacto-gov)** to integrate with **pacto-squad-sponsor**. This repo ships standalone; pacto-gov wires in at deploy time.

**Reference pattern:** `SquadAdmin` + `SquadAdminExt` (`postInitialize`). Sponsor mirrors the same split — see `TECH_SPEC.md` §4.3.

**Note (undecided):** `SquadAdmin` / `SquadAdminExt` may eventually move to their own repo (same modular pattern as pacto-squad-sponsor). If that happens, both pacto-gov and this repo should depend on the shared admin module package rather than duplicating logic.

---

## 1. Factory — call `SquadSponsorExt.postInitialize`

When `NavePirataFactory.deployNavePirata` (or equivalent) completes for a squad:

1. Resolve pre-deployed **`SquadSponsorExt` clone** for that squad (from `SquadSponsorFactory` registry / app `squadId`).
2. Deploy **`SquadSponsor`** hat clone if not already present.
3. Call **`extClone.postInitialize(topHatId, squadSponsorClone)`** — args aligned to `SquadAdminExt.postInitialize`.
4. **`postInitialize` callers (match SquadAdminExt):** `NavePirataFactory`, Ext **`addressOwner`**, or **Hats tree owner**.

**Effect:** Hat-based eligibility (`SquadSponsor` base) activates for that squad and **overrides** address-based entries on the pre-deployed Ext. Vault `topHatId` link set in same flow.

---

## 2. Deploy / record `SquadSponsor` (base) at gov deploy

- Deploy **`SquadSponsor`** hat **clone** when pacto-gov **or** custom hat tree is wired.
- Factory does **not** redeploy vault clone or paymaster — vault + Ext clones already exist from first deposit.
- **`SquadSponsorFactory`** + paymaster remain chain singletons; only squad clones multiply.

---

## 3. Do not duplicate sponsor address registries

| Data | Lives in | pacto-gov must NOT |
|------|----------|-------------------|
| Sponsor gas eligibility (address mode) | **`SquadSponsorExt`** in pacto-squad-sponsor | Add parallel crew-address mapping for gas |
| Crew roster / QM state | pacto-gov (`Quartermaster`, etc.) | Conflate with sponsor Ext |
| Hat wearers (post-wiring) | Hats Protocol + **`SquadSponsor`** base | Re-implement `isWearerOfHat` checks for gas |

When hats are active for a squad, sponsorship eligibility reads **Hats only** (via `SquadSponsor` base). pacto-gov modules should not maintain a second list of “who gets sponsored gas.”

**App responsibility:** When a member shares EVM in squad inbox (pre-hat wiring), app prompts **`addressOwner`** (first depositor, or transferred owner) to call **`setPermittedAddress`** on the squad’s Ext clone.

---

## 4. `SquadAdminExt` alignment

Audit pacto-gov for:

- [ ] `SquadAdminExt.postInitialize` signature and auth (`onlyFactory` / owner / hats owner).
- [ ] Order of operations: Ext already deployed → gov deploy → `postInitialize` on Ext.
- [ ] Whether `SquadAdmin` base is deployed in same tx batch as factory gov deploy (sponsor base should follow the same batching).

Copy auth modifiers and event shapes where possible so operators learn one lifecycle.

---

## 5. Registry / deployment artifacts

Optional (nice-to-have, not blocking sponsor v1):

- [ ] Pointer to chain `SquadSponsorVault` / paymaster / Ext in `INavePirataRegistry.Deployment` **or** shared `deployments/<chainId>/sponsor.json` consumed by app + factory.
- [ ] Document `squadId` ↔ `topHatId` linkage source of truth (vault after `postInitialize`).

---

## 8. Safe ERC-4337 module (Path A)

When a squad Safe is deployed or configured via pacto-gov / app:

- [ ] Enable Safe **ERC-4337 module** (or deploy Safe version with native 4337 support) so Safe can be **`userOp.sender`**.
- [ ] Record Safe + module addresses in deployment artifacts for paymaster / app config.
- [ ] App builds UserOps with `sender = safeAddress`, not separate relay txs.

See sponsor spec §5.2 (D18).

---

## 9. Out of scope for pacto-gov (this milestone)

| Item | Owner |
|------|--------|
| Crew hat mint sponsorship | **Not v1** — captain-controlled minting; revisit later |
| Paymaster / vault accounting | pacto-squad-sponsor |
| Low-balance alerts | Pacto app (off-chain) |
| ERC-4337 / 7702 transport | App + Alchemy + paymaster in sponsor repo |
| Safe 4337 module enablement at Safe deploy | pacto-gov / app (§8); paymaster validation in sponsor repo |

---

## 10. Testing checklist (pacto-gov PR)

- [ ] **Mainnet fork** test (D19): pool funded on Ext **before** gov → `deployNavePirata` → `postInitialize` → hat wearer sponsored.
- [ ] Squads without gov deploy continue on Ext address mode only.
- [ ] Custom hat tree (no full PactoGov): same **`postInitialize`** pattern as **`PactoAdmin`** — norm in pacto-gov today.

---

*Track implementation in pacto-gov; keep this file updated when factory interface stabilizes.*
