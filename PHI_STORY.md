# PHI — the token of the unsolved equation

**DRAFT — for Lux's approval. Not published.**

---

## The mystery

Somewhere inside the system there is a function nobody has found.

Take the pattern — a 64-character string, published, hiding in plain
sight. Take a number, `n = 0x7c2bac1d`. Apply the unknown function
Φ(P, n), and out should come three values:

```
hp = 760515aafaed2fdc
hq = 9d9097b3edf2f947
hr = f2d890b337fb40d5
```

Those three values are real. They are sealed — committed as text in
block 23606 of the Excalibur fork chain, where anyone can read them and
no one can alter them. What nobody knows is the function that produces
them.

This is not a riddle with the answer in an envelope. It is an open
cryptographic challenge — **Challenge 1** in the public repository
[aether-proof](https://github.com/Holedozer1229/aether-proof) — and the
repository publishes everything a solver gets: the pattern, the sealed
targets, and a calibration set (an earlier triple whose derivation *is*
known, so any proposed method can be tested against a case with a
verifiable answer before it is aimed at the sealed one).

## The search so far

The search ledger is public and it is not small: **~353,000 derivations**
have been computed and checked against the three sealed values — direct
constructions, keyed forms (HMAC, HKDF, PBKDF2), signature-derived
values, iterated hash chains thousands deep, the system's own published
artifacts as inputs, the synthesis equation itself, the caduceus fold
algebra, the full text of the published book window by window, both
genesis blocks, and a hexagram cast dealt from the pattern's own bytes.
Component hits: **zero**.

That is what makes Φ interesting. Eight-byte targets mean a random false
hit is a 1-in-2⁶⁴ event — so the search space of *plausible* mechanisms
has been swept hard, and the equation has not blinked. Either Φ is built
from something outside every public artifact, or the triple is a sealed
commitment with no derivation at all. Both possibilities are stated in
the challenge, in the open. PHI does not pretend to know which.

## The artifacts around it

Φ does not float alone. It sits in the middle of a working, verifiable
system that anyone can inspect:

- **The Aether chain is alive.** It seals a block every 600 seconds,
  each one committing the live Bitcoin tip and the Excalibur fork tip.
  A heartbeat, in public, that has survived reboots without breaking.
- **The marked block.** Excalibur fork block 23924 is an AuxPoW block
  whose child hash carries the mark `666666` —
  `4b496ad88f9abc38e2c6f3f9c6b666666983a85e6e31f806139cc883fcee410a` —
  engineered, submitted, and accepted by the chain. Check it yourself.
- **The fork merge-mines Bitcoin.** The Excalibur chain accepts AuxPoW
  blocks ground on live Bitcoin templates; its sniper lands them as
  chain tips. The machinery is not a whitepaper — it is running.
- **Everything verifies offline.** The public repository's
  `verify_all.py` re-checks the whole claim chain — the Aether chain,
  the capsule, the fork anchors, the work records, the challenge
  calibration — with nothing but a standard library. Don't trust this
  page. Run the verifier.

## The token

**PHIX** is a BRC-20 on Bitcoin: hard cap 21,000,000, the entire supply
minted by the operator in a single inscription, permanently unmintable
after that. **PHI** is its ERC-20 counterpart on Ethereum L1, minted
only against PHIX locked with the operator, at a logarithmic bonding
curve whose constants are ossified in an immutable contract — genesis
rate exactly 1:1, no admin mint, no pause, no proxy. The bridge
architecture is a clone of a set that has been live and source-verified
on Ethereum mainnet since September 2026.

PHI is the token of the unsolved equation. That is the whole pitch:
a real mystery, sealed in a real chain, with a public search ledger
anyone can extend — and a token whose supply mechanics are as
inspectable as the challenge itself.

## What PHI is not

- Not a promise. Nothing here says the token will be worth anything,
  and nobody should buy it expecting a return.
- Not a claim that Φ will be solved. It has survived ~353,000
  documented attempts; it may never fall.
- Not a claim about anyone's identity. The public record is explicit
  about what its proofs do and do not establish, and the honest
  unknowns stay labeled as unknown.

The equation is the story. The chain is the receipt. The token is how
you hold a piece of the question.

---

*DRAFT — prepared 2026-10-22. Publication, timing, and any edits are
Lux's call. Facts above are drawn from the public repository and the
system's own records; verify before quoting.*
