# PHI — the unsolved equation, as a bridge

**Status: built and tested. NOT deployed. Nothing has been broadcast.**

PHI is a faithful clone of the live ATEX/SKYNT bridge architecture
(`Holedozer1229/atex-bridge`, on Ethereum mainnet since 2026-09-26) under
new names, with the original's operator-hygiene mistake fixed from birth.

| Layer | Asset | Where |
|---|---|---|
| Bitcoin | **PHIX** — BRC-20, 21,000,000 max = lim, 18 decimals | inscription payloads in `payloads/` (not yet inscribed) |
| Ethereum L1 | **PHI** — ERC-20 (`Phi.sol`) + `PhiBridge.sol` | `contracts/src/` (not yet deployed) |

Same logarithmic bonding curve, same operator model, same ossified
constants as the ATEX set. One deliberate difference: the bridge is
constructed with a **fresh operator from birth** — never the deployer —
so there is no window where an exposed key holds the operator role.
See `PHI_DEPLOYMENT.md` for the full runbook and funding gates.

## Tests (verified 2026-10-22)

- Foundry contracts: **19/19 pass** (`contracts/test/PhiBridge.t.sol`)
- Operator daemon: **34/34 pass** (`contracts/operator/test_operator.py`)

Run them:

```bash
cd contracts
forge install   # fetches forge-std
forge test

cd operator
python3 test_operator.py   # needs embit, web3, eth-abi
```

## Layout

- `contracts/src/Phi.sol`, `contracts/src/PhiBridge.sol` — the L1 pair
- `contracts/operator/` — the bridge operator daemon (BTC wallet,
  inscription builder, indexer adapter, claim/lock flows, rotation tool)
- `payloads/` — BRC-20 deploy + full-supply mint inscription payloads
  for PHIX (prepared, not inscribed)
- `DESIGN.md` — architecture
- `PHI_DEPLOYMENT.md` — deployment runbook (read the funding gates first)
- `PHI_STORY.md` — draft story — **DRAFT, not an announcement**
