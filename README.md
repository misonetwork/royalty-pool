# `royalty_pool`

> Accumulator-based royalty distribution: holders stake share tokens, callers deposit revenue, and every deposit is split pro-rata with O(1) work per deposit and per claim.

**Layer:** `lib` — a primitive, not core protocol and not an extension (it attaches to nothing miso-specific). A `RoyaltyPool<Share, Currency>` is a derived object of any UID-bearing parent.

## How it works

The pool keeps a `cumulative_reward_per_share` index. A deposit of `v` across `S` staked shares advances the index by `v · PRECISION / S`; a stake claims `shares · (index − last_claim_index) / PRECISION`. Neither operation iterates over holders, so cost does not grow with the number of stakers.

Claims advance a stake's index only by the amount its reward actually consumed, so sub-base-unit remainders stay credited and fractional holders recover their full proportional share over time rather than losing it to truncation.

## Honest addresses

The derivation key encodes both type parameters, so a pool's address is determined by `(parent, Share, Currency)` — the same parameters that produce the object. The pool at a canonical address is therefore necessarily of the matching type, and (being `key`-only, with `share` as its only consumer) necessarily shared. A pool created with a foreign `Share` claims a different, unpaid address: it can neither impersonate nor block the real one.

That property is what lets payers deliver to a derived address before the pool exists — funds wait at an address only the correctly-typed, shared pool can ever claim, and folding them in is permissionless.

## License

Apache-2.0
