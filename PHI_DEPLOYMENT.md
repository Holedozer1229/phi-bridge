# PHI / PhiBridge L1 deployment — runbook (NOT YET DEPLOYED)

Status: **prepared, unfunded, undeployed.** Everything in this directory is
built and tested. Nothing has been broadcast. This runbook is the exact
sequence to follow when Lux gives the word and the funding gates below are
met.

The PHI set is a faithful clone of the ATEX/SKYNT set
(`~/workspace/atex-bridge/`, live on mainnet since 2026-09-26) under new
names: **PHIX** (BRC-20, Bitcoin) ↔ **PHI** (ERC-20, Ethereum L1), same
logarithmic bonding curve, same operator model, same ossified constants.

## The two funding gates (stated plainly)

Nothing below can start until both exist. Amounts are priced at fire time —
gas and inscription fees move; this runbook quotes nothing.

1. **A deployer with ETH on Ethereum L1** — enough for three transactions
   (deploy PHI, deploy PhiBridge, `setBridge` wiring) at the fee caps in
   `operator/deploy_l1.py`. The deployer key is used transiently and never
   stored.
2. **A BTC wallet for the PHIX inscriptions** — enough confirmed BTC for the
   deploy inscription plus the full-supply mint inscription (commit +
   reveal fees each), at fire-time feerates.

## Operator hygiene — fixed from birth (read first)

The original ATEX set was deployed with `operator = deployer`, and the
deployer key was afterwards exposed — forcing a rotation scramble. PHI must
not repeat this. The rule for this set:

- **Before deploying anything**, generate the operator key **fresh, offline**
  (e.g. `operator/eth_addr.py` flow / `rotate_operator.py` conventions:
  key on paper/0600 file, address only leaves the offline step).
- The operator is **never the deployer**. `deploy_l1.py` enforces this:
  it reads the operator address from `OPERATOR_ADDRESS` and aborts if it is
  unset or equals the deployer.
- The bridge is **constructed with the fresh operator directly** — the
  equivalent of `setOperator` happens at birth, in the constructor. There
  is no window where an exposed key holds the operator role.
- The operator private key is used only by the daemon
  (`OPERATOR_ETH_KEY_FILE`, mode 0600). It is never pasted into chat, never
  committed, never logged.
- Ownership stays with the deployer until Lux decides on
  `renounceOwnership`; renouncing is a one-way door and is **not** part of
  the deploy sequence.

## Deploy order

### 0. Pre-flight

- [ ] Both funding gates met (ETH deployer funded; BTC wallet funded and
      confirmed).
- [ ] Fresh operator key generated offline; `OPERATOR_ADDRESS` = its
      address; key file stored 0600, offline backup made.
- [ ] **PHIX ticker check on a live BRC-20 indexer** — ticks are
      first-come-first-served. If `PHIX` is taken, STOP: the deploy
      inscription sats are burned for nothing. (Same warning as the ATEX
      design doc; no indexer was reachable from this VM at build time, so
      this check must happen at fire time.)
- [ ] `cd ~/workspace/phi-bridge/contracts && forge test` — 19/19.
- [ ] `cd operator && python3 test_operator.py` — 34/34 (needs the
      embit/web3 venv; see OPERATOR.md).

### 1. Ethereum side (`operator/deploy_l1.py`)

```
OPERATOR_ADDRESS=0x<fresh operator> python3 deploy_l1.py < deployer_key.txt
```

The script, in order:

1. Deploys `Phi` (name "Phi", symbol "PHI", 18 decimals).
2. Deploys `PhiBridge(token=Phi, operator=OPERATOR_ADDRESS)`.
3. Calls `Phi.setBridge(PhiBridge)` — exactly once, owner-only.
4. Verifies on-chain: `phi.bridge() == bridge`, `bridge.token() == phi`,
   `bridge.operator() == OPERATOR_ADDRESS`, `bridge.mintRate() == 1e18`
   (genesis 1:1).
5. Does **not** renounce ownership.

Fee discipline is in the script (base-fee abort caps; the `to` field is
always set and asserted — the ATEX set's first wiring attempt burned gas
by omitting it; `wire_l1.py` is kept as the recovery tool if wiring ever
needs to be finished separately — fill its `PHI`/`BRIDGE` constants from
the deployment record first).

Record the results here at fire time:

- PHI token: `TBD`
  deploy tx: `TBD`
- PhiBridge: `TBD`
  deploy tx: `TBD`
  constructor args: token=PHI, operator=FRESH (never deployer)
- setBridge wiring tx: `TBD`

### 2. Source verification

- [ ] Verify both contracts on Sourcify (exact match expected — same
      source, solc 0.8.24, optimizer 200 runs, Cancun), as was done for
      the ATEX set.

### 3. Bitcoin side (PHIX inscriptions)

Payloads are prepared in `~/workspace/phi-bridge/payloads/`:

- `brc20-deploy-phix.json` —
  `{"p":"brc-20","op":"deploy","tick":"PHIX","max":"21000000","lim":"21000000","dec":"18"}`
- `brc20-mint-phix.json` —
  `{"p":"brc-20","op":"mint","tick":"PHIX","amt":"21000000"}`

- [ ] Re-run the live ticker check (step 0) immediately before inscribing.
- [ ] Inscribe the **deploy** from the operator BTC wallet; wait for
      confirmation.
- [ ] Inscribe the **mint** (full 21M supply, `lim == max`, to the operator
      address). After this mint the tick is permanently unmintable by
      anyone; all later user acquisition is via `transfer` inscriptions
      from the operator against EXCAL locks, exactly as in the ATEX model.

Honest constraint (carried over from the design): BRC-20 indexers accept
any well-formed mint; the "operator-only supply" property comes from the
operator self-minting the entire capped supply in one inscription, not
from protocol enforcement.

### 4. Wire the daemon

- [ ] Set `BRIDGE_CONTRACT` to the deployed PhiBridge address (config has
      **no default** — the original hardcoded the live ATEX bridge; that
      mistake is not repeated here).
- [ ] Set `OPERATOR_BTC_ADDRESS` / `OPERATOR_BTC_WIF_FILE` /
      `OPERATOR_ETH_KEY_FILE` (operator = the fresh key from step 0).
- [ ] Set `INDEXER_URL` (+ key) and **verify the indexer mapping**
      (`operator/indexer.py` is marked UNVERIFIED): run
      `python3 indexer.py <operator_btc_address>` and confirm the printed
      transfers match the indexer's own explorer before enabling the
      PHIX-receiving flows.
- [ ] Dry-run: `DRY_RUN=1 python3 daemon.py --once` — inspect the flow
      report (which flows are ENABLED) and the log, then go live.

### 5. Go-live checklist

- [ ] Deployment record above filled in (addresses + txids).
- [ ] Sourcify exact-match verification live for both contracts.
- [ ] PHIX deploy + mint inscriptions confirmed on Bitcoin; supply visible
      on the indexer under the operator address.
- [ ] Daemon running with all four flows in the intended state; first
      dry-run log reviewed.
- [ ] Claim flow tested end-to-end with a dust amount before accepting
      real deposits (`operator/claim.py`, OPERATOR.md).
- [ ] Deployer key retired/emptied per Lux's instruction; ownership /
      renounce decision recorded.
- [ ] Public announcement uses `PHI_STORY.md` (DRAFT — Lux approves the
      final text). No return promises, no price talk — ever.

## Layout of this directory

```
phi-bridge/
  DESIGN.md            renamed clone of the ATEX design doc
  PHI_DEPLOYMENT.md    this runbook
  PHI_STORY.md         launch narrative (DRAFT)
  payloads/            PHIX deploy + mint inscription bodies
  contracts/           Foundry project (src/Phi.sol, src/PhiBridge.sol,
                       test/PhiBridge.t.sol — 19 tests) + operator/
                       (daemon, 34-check suite, OPERATOR.md runbook)
```
