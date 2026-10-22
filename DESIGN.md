# PHIX ↔ PHI Bridge — Design

Lux's directive (2026-09-26): "Design it the most logical best way, you have the reins,
make it unstoppable." Custody answer: **the node operator** (Lux).

## The system

Three assets, two bridges, one operator:

```
EXCAL (Excalibur mainnet)  <--1:1-->  PHIX (BRC-20, Bitcoin)  <--log curve-->  PHI (ERC-20, Ethereum L1)
```

- **EXCAL**: native coin of the Excalibur chain. Mainnet goes public (height 143+, serve-only → seeded).
- **PHIX**: wrapped EXCAL as a BRC-20 on Bitcoin. Fixed supply, operator-issued.
- **PHI**: ERC-20 on Ethereum L1, minted only against PHIX locked with the operator,
  at a logarithmic bonding-curve rate. No other mint path exists.

## PHIX (BRC-20)

Honest constraint first: BRC-20 indexers treat any well-formed mint inscription as valid.
The protocol **cannot** enforce "mint only against locked EXCAL". The logical wrapped
model inside that constraint: the operator deploys and self-mints the entire supply in
one inscription, then distributes only via transfers against EXCAL locks. No one else
can ever mint. Supply is capped by Bitcoin, not by promise.

Deploy inscription (`phix-deploy.json`):
```json
{"p":"brc-20","op":"deploy","tick":"PHIX","max":"21000000","lim":"21000000","dec":"18"}
```
- `max` 21,000,000 — Bitcoin-evocative hard cap.
- `lim` = `max` — single full-supply mint by the operator. After that mint, the tick
  is permanently unmintable by anyone.
- `dec` 18 — matches PHI/EXCAL divisibility (1 PHIX = 1e18 base units).

Mint inscription (`phix-mint.json`): `{"p":"brc-20","op":"mint","tick":"PHIX","amt":"21000000"}`
→ 21M PHIX to the operator's BTC address. All user acquisition after that is via
`transfer` inscriptions from the operator.

Ticker check: BRC-20 ticks are first-come-first-served. No PHIX BRC-20 surfaced in web
search (2026-09-26), but no indexer was reachable from the VM (Hiro API deprecated,
ordiscan Cloudflare-blocked). **Verify against a live indexer immediately before
inscribing the deploy** — if taken, the deploy sats are burned for nothing.

## PHI (ERC-20)

- Name "Phi", symbol "PHI", 18 decimals.
- Mint: only `PhiBridge.lockPhix` (operator-attested). Burn: permissionless by holders.
- No admin mint, no pause, no proxy. Immutable.

## PhiBridge (Ethereum L1)

The conversion rate is a **logarithmic bonding curve** on PHI supply, priced at the
margin (simple, exact, no on-chain iteration):

```
rate(S) = R0 / (1 + α · ln(1 + S / S_ref))        [PHI per PHIX, S = PHI supply]
```

- `R0 = 1.0` — genesis rate is 1:1 (1 PHIX → 1 PHI).
- `α = 1.0` — curve steepness.
- `S_ref = 1,000,000 PHI` — scale.
- All constants, ossified at deploy. Monetary policy can't be changed later.

Sample rates: S=0 → 1.000 · S=1M → 0.591 · S≈6.4M → 0.333 · S≈147M → 0.167.
Early bridgers are rewarded; late supply costs exponentially more PHIX. The integral
A(S) = (S_ref/R0)·[(1−α)(S/S_ref) + α(1+S/S_ref)·ln(1+S/S_ref)] is documented for
off-chain quoting; the contract prices at the margin.

Functions:
- `lockPhix(bytes32 btcTxid, uint256 phixAmount, address to)` — `onlyOperator`.
  Replay-protected via `usedTxids`. Mints `phixAmount · rate(S) / 1e18` PHI to `to`.
  Emits `PhixLocked(btcTxid, to, phixAmount, phiMinted)`.
- `burnForPhix(uint256 phiAmount, string btcAddress)` — anyone. Burns the caller's
  PHI, emits `PhiBurned(from, btcAddress, phiBurned, phixReleased)` with
  `phixReleased = phiAmount · 1e18 / rate(S)` at pre-burn supply. The operator's
  daemon watches the event and sends the PHIX transfer inscription on Bitcoin.
- `mintRate()` — view, current PHI-per-PHIX.
- `setOperator(address)` — `onlyOwner` (Lux). Rotation, not removal.

Fixed-point: 1e18 (UD60x18 style). `ln` implemented dependency-free in-contract
(log2 by bit decomposition + refinement, × ln2). Tested against known values.

## Flows

1. **EXCAL → PHIX** (1:1): user sends EXCAL to the operator's Excalibur address;
   daemon sees it, inscribes PHIX `transfer` to the user's BTC address.
2. **PHIX → PHI** (log curve): user sends PHIX `transfer` inscription to the
   operator's BTC address; daemon verifies, calls `lockPhix`; PHI minted to the
   user's ETH address.
3. **PHI → PHIX** (log curve): user calls `burnForPhix`; daemon sees the event,
   inscribes PHIX `transfer` to the user's BTC address.
4. **PHIX → EXCAL** (1:1): user sends PHIX to the operator's BTC address with an
   Excalibur address memo; daemon releases EXCAL.

## Trust model (stated plainly)

- Trustless: PHIX supply (Bitcoin), PHI supply and curve (Ethereum), burn path
  (permissionless on-chain).
- Trusted: the node operator holds locked PHIX/EXCAL and fulfills redemptions.
  If the operator disappears, redemptions halt — PHIX and PHI themselves stay
  transferable. This is the federated tradeoff; a fully trustless BTC↔ETH bridge
  is a research project. Upgrade path: operator → federated multisig → light-client
  relay, without changing the curve or token contracts.

## Why this is "unstoppable"

- No pause switches, no upgradeable proxies, no admin mint.
- Curve parameters are compile-time constants.
- BRC-20 supply is Bitcoin-final; ERC-20 supply is curve-final.
- Every PHI in existence maps to a logged `btcTxid` lock — backing is auditable.
- The contracts don't depend on any off-chain server to *exist*; only redemptions
  need the operator awake.

## Deployment checklist

1. Indexer check: PHIX tick free (live query, right before deploy).
2. Fund operator BTC wallet → inscribe deploy → inscribe full-supply mint.
3. Fund Ethereum deployer → deploy `Phi`, deploy `PhiBridge(operator=Lux)`,
   wire bridge address into PHI.
4. Operator daemon: watches Excalibur chain (EXCAL locks), Bitcoin (PHIX transfers),
   Ethereum (PhiBurned events); inscribes ATX transfers; calls lockPhix.
5. EXCAL mainnet public: real seed endpoint in the miner package, DNS, explorer
   via the existing bridge.

## Needs Lux (cannot proceed without)

- Funded Bitcoin wallet (deploy + mint inscription fees) — key via secure vault or Lux signs.
- Funded Ethereum L1 deployer (contract deployment gas) — same.
- Operator BTC address, operator ETH address, EXCAL bridge address.
- Public endpoint for the EXCAL mainnet seed.
