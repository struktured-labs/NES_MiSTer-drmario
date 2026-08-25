# Deployed bitstreams recovered from the MiSTer SD card

**Recovered 2026-08-25 from 10.42.0.225 (`/media/fat/_Console/`), read-only.**

These four were **DEPLOYED** — they ran on hardware — and existed on **that SD
card only**. A scan of **275 `.rbf` files across 6 local trees** found none of
them. They cannot be rebuilt: the settings that produced them are not in any
repository (see `../PROVENANCE.md`). If the card had failed they were gone
permanently, which is the same exposure class as the ignored/untracked layer,
one step further out — not "one working tree on one box" but "one card, never
copied to a box at all".

Nine NES cores sit on that card; the other five ARE held locally. So the
deployed-but-unheld gap is a recurring pattern in how the card was populated,
not a single stray file.

| md5 | size | SD mtime | file | attribution |
|---|---|---|---|---|
| `7a538f755a32649eaaf237f99ffcdf85` | 3,491,760 | 2026-07-27 23:05:32 | `NES_20990101.rbf` | **almost certainly commit `fcd4ae3`, tag `mister-winner-deploy-20260727`** — see below. THIS IS THE CORE THE Dr. MARIO `.mgl` FILES ACTUALLY BOOT. |
| `6fa85844a255df936259678394838aed` | 3,524,968 | 2026-08-04 06:44:20 | `NES_stomper180s20_20260804.rbf` | unattributed |
| `72d5a92fc73080baa9d6fe74da7810fd` | 3,524,856 | 2026-08-04 13:54:46 | `NES_stomper180s20b_20260804.rbf` | unattributed |
| `be266883c5b79759a615220e457fa3af` | 3,561,472 | 2026-08-01 02:18:32 | `NES_tuckmb_20260731.rbf` | unattributed |

## Attribution of `NES_20990101.rbf` — STRONG, but NOT a hash match

We do not hold the build output, so no byte proof is possible. Four converging
lines:

1. **Tag name encodes the date.** `mister-winner-deploy-20260727` → `fcd4ae3`.
2. **SD mtime matches it.** Commit 2026-07-27 19:20:44; card written 23:05:32
   the same evening — 3h45m later, i.e. commit → fit → deploy.
3. **Only two commits exist that day**, 13 s apart: `fcd4ae3`
   ("single-copro DE10 fit (strip P1)") and `3c2d4f6` ("dual-copro … both
   copros retained").
4. **★ A HARDWARE MEASUREMENT DISCRIMINATES, AND IT PREDATES THE HYPOTHESIS.**
   Running the AB copro cart on this very core gave `TGT_C1 = 0x50` (NES open
   bus at `$5000`) with `$5200` answering — the single-copro signature.
   `fcd4ae3` instantiates one `CoproDrMario` at `WIN=0101_001`; `3c2d4f6`
   instantiates two. So the measurement **excludes `3c2d4f6`**. It was taken to
   answer a different question ("does the deployed core have a copro at all")
   before either commit was known, so it cannot have been fitted to this
   conclusion.

Report as *almost certainly* `fcd4ae3`, never as proven.

## Verification of this preservation

Hashed on the SD **before** transfer, re-hashed locally **after**: 4/4 match on
both md5 and size. The SD was re-read afterwards and its hashes are unchanged —
the operation was read-only, and nothing on the card was modified or deleted.
