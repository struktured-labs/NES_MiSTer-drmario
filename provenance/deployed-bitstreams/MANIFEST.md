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
| `6fa85844a255df936259678394838aed` | 3,524,968 | 2026-08-04 06:44:20 | `NES_stomper180s20_20260804.rbf` | **PROVEN — commit `7f6ba69`**, whose message records the hash itself |
| `72d5a92fc73080baa9d6fe74da7810fd` | 3,524,856 | 2026-08-04 13:54:46 | `NES_stomper180s20b_20260804.rbf` | **UNATTRIBUTABLE** — no commit, no tag, no recorded hash |
| `be266883c5b79759a615220e457fa3af` | 3,561,472 | 2026-08-01 02:18:32 | `NES_tuckmb_20260731.rbf` | **strong — commit `b498764`, tag `core-tuckmb-20260731`** |

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


## Attribution of the other three

### `6fa85844` — PROVEN, and it took ten seconds

Commit **`7f6ba69`** (2026-08-04 02:47) reads:

> `#47 CMD-8 stranded scan vendor + strand20 firmware (e970e9ab); rbf 6fa85844 slack +0.102 ALM 37591 seed 2`

**The author wrote the artifact's md5 prefix into the commit message.** No
archaeology, no inference, no hardware measurement — `git log --grep` found it
directly, three weeks later. It even carries the fit result (slack +0.102, ALM
37,591, seed 2). SD mtime 06:44 is ~4 h after the commit.

★ **This is the practice to copy.** Of these four artifacts, the only one with a
*certain* attribution is the one whose hash was recorded at commit time. The
others needed converging circumstantial evidence, or could not be named at all.
Recording `md5 → commit` when a bitstream is built costs one line and removes
the whole problem.

### `be266883` (tuckmb) — STRONG

Tag **`core-tuckmb-20260731`** → commit **`b498764`** (2026-07-31 22:18), "tuck
mailbox RTL + tuck-enabled firmware (751b6ce9)". The tag body reads *"NES.rbf:
tuck mailbox RTL + firmware 751b6ce9, 87% ALM, timing closed"*. Tag name matches
the filename exactly, and the SD mtime (2026-08-01 02:18) is 4 h after the
commit. Not hash-proven — the tag records ALM and firmware, but not the md5.

### `72d5a92f` (stomper180s20**b**) — UNATTRIBUTABLE, and that is the finding

No commit, no tag, and no recorded hash names it. The only commit that day
(`7f6ba69`) produced the **`a`** variant; this one was written to the card
**11 hours later**, at 13:54. Most plausibly a re-fit at a different seed — the
`a` build records "seed 2" — but that is a guess and it is labelled as one.

⇒ **A deployed artifact exists that was built from a tree state which may never
have been committed.** Same disease as the uncommitted `NES.qsf`, now visible in
a shipped bitstream: we possess the file (thanks to this preservation) and can
never say what made it.
