# Canon winner core — AS-BUILT provenance record

**Preserved 2026-08-25.** This branch is a RECORD, not a proposal. It changes no
build and asks for no merge.

## Why this exists

`/home/struktured/projects/NES_MiSTer-winner` — the tree that produced the
shipped winner core — carries an **uncommitted** `NES.qsf` plus a set of
untracked and gitignored artifacts. The settings that built the shipped
bitstream therefore existed in **exactly one working tree on exactly one box**,
alongside the only copies of the bitstreams themselves. One `git checkout --`,
one `git clean`, or one disk failure and the record of how the shipped core was
made would be gone. We have a standing memory about a harness destroying work
with `git checkout --`, so this is a realised risk, not a hypothetical one.

Consequence worth stating plainly: **the shipped winner core is not
reproducible from a clean clone.** That is a pre-existing condition; nothing in
this branch fixes it, and fixing it — deciding whether HEAD should adopt these
settings — is the owner's call and a separate change.

## What the canon tree looked like

* HEAD: `08f23434cac449db7ee5f641958fcc00c616c29d` ("respin-144 take 2")
* `NES.qsf`: **modified, uncommitted**, md5 `704e475b1928bd35f04bc12c90033cbb`,
  mtime 2026-08-21 14:20:54 −0400 (the Aug-21 build)
* This branch is based on that same commit, so the as-built settings sit
  directly on top of the commit they were built from.

### How the as-built qsf differs from committed HEAD

Recorded verbatim in `as-built/NES.qsf.diff-vs-08f2343` (17 lines). Substance:

1. `EDA_SIMULATION_TOOL "QuestaSim (Verilog)"` + `EDA_OUTPUT_DATA_FORMAT` +
   `EDA_NETLIST_WRITER_OUTPUT_DIR output_files/simnet` — simulation netlist
   writing, absent from HEAD.
2. Duplicate `SYSTEMVERILOG_FILE` / `VERILOG_FILE` assignments for
   `CoproDrMario.sv`, `LeafEval.sv`, `copro6502.v`, `copro_alu.v` — already
   supplied via `files.qip`, so these are redundant rather than additive.

**This is why the Aug-21 numbers are not a control for any HEAD build.** They
were produced under settings that do not exist in git. Any "did my change break
timing?" question needs a paired fit against the exact parent commit, never a
comparison against a stored table or a previous build's report.

## What is preserved here

| path | what | why it was at risk |
|---|---|---|
| `as-built/NES.qsf.as-built` | the exact uncommitted qsf | uncommitted |
| `as-built/NES.qsf.diff-vs-08f2343` | its diff vs HEAD | derived |
| `as-built/run_fit.sh`, `sweep_seeds.sh` | the build drivers | **untracked** |
| `SEED_SWEEP_TABLE.csv` | the seed-sweep verdicts | **gitignored** |
| `output_files/*` (summaries, `.sta.rpt`, flow/asm/eda) | the only timing evidence for the shipped build | **gitignored** |
| `fit-logs/*.log` | 14 per-fit logs incl. every seed | **untracked** |
| `seed-backups/tmp_seed{7,9}_backup/` | per-seed fit + sta summaries | **gitignored** |
| `rbf-manifest.txt` | md5 + size of all 7 bitstreams | 6 of 7 **untracked** |
| `large-reports-not-copied.txt` | md5 + size of the two huge reports left behind | so their absence is visible |

⚠ The `.rbf` files themselves are **not** committed (≈3.5 MB each). Only the
manifest is here, so a future reader can tell whether a bitstream they hold is
one of these. **6 of the 7 are untracked and still exist only on that one box.**

### Bitstream inventory

| md5 | bitstream | git | timing |
|---|---|---|---|
| `caa5b5c6` | `NES_stomper180s20t3_20260805_seed13.rbf` | untracked | **the only one that closed** (+0.051 ns) |
| `1da3d057` | `..._seed7_TIMINGFAIL.rbf` | untracked | MISS −0.074 |
| `529ada5d` | `..._seed9_TIMINGFAIL.rbf` | untracked | MISS −0.020 |
| `beb1104b` | `..._seed11_TIMINGFAIL.rbf` | untracked | MISS −0.060 |
| `5c2a3be7` | `..._seed15_TIMINGFAIL.rbf` | untracked | MISS −0.504 |
| `26b004ab` | `..._seed17_TIMINGFAIL.rbf` | untracked | MISS −0.132 |
| `de7dea35` | `NES_theta400_20260809.rbf` | **tracked** | recorded in commit `b20864a` |

The Aug-21 build in `output_files/` reports **90% ALM** (37,664 / 41,910) and
binds on `emu|pll|…counter[0]|divclk` = **clk85** at **+0.165 ns**;
`counter[2]` = `clk` sits at +3.007 ns. That ~18x gap between the copro's fast
domain and the host-bus domain is the cost driver for any future RTL on this
core.

## Handling rules

* The canon tree is **read-only**. Everything here was copied out; nothing was
  checked out, stashed, cleaned, reset or committed inside it. Its working
  state IS the artifact. Verified unchanged before and after this capture
  (`git status --porcelain` still reports ` M NES.qsf`, same md5).
* Do **not** merge these settings onto a mainline as a "fix". The record is the
  deliverable; adopting the settings is a separate, owner-level decision.

## Is this preservation SUFFICIENT to rebuild? — verified, with one honest limit

Preserving a record is worth little if the record is incomplete, so this was
checked rather than assumed. Every file reference was resolved transitively out
of the project files (`NES.qsf` -> `*.qip` -> nested qips), for both the
committed HEAD qsf and the as-built one, against a **clean checkout of
08f2343**:

| qsf | file references | missing |
|---|---|---|
| committed HEAD | 98 | 0 |
| **as-built** | **102** | **0** |

The as-built qsf's extra 4 references are the redundant copro file assignments
already supplied by `files.qip`; it introduces no new source. One reference is
computed in TCL — `pll_q[regexp digits of $quartus(version)].qip` — which
resolves to `sys/pll_q23.qip` under Quartus 23.1std.1 and is present
(`pll_q13`/`pll_q17`/`pll_q23` all ship in the tree).

The three inputs that were genuinely absent from a fresh checkout are now
covered: `run_fit.sh` and `sweep_seeds.sh` are preserved here, and `build_id.v`
— which `NES.sv:69` `` `include ``s — is generated by the `sys/build_id.tcl`
PRE_FLOW script (verified by invoking it the way Quartus does, in two
independent fresh worktrees).

⇒ **A clean clone at 08f2343 plus this branch contains every file the build
references.** That is a real improvement on where we were this morning.

⚠ **BUT INPUT COMPLETENESS IS NOT BIT-REPRODUCIBILITY, AND THIS DOES NOT CLAIM
IT.** Having every input is necessary, not sufficient: identical output also
depends on the Quartus version, the seed, and the fitter's determinism, none of
which is demonstrated here. The only way to establish that is to rebuild and
compare against the shipped bitstream's md5 (`caa5b5c6…`, seed 13) — roughly a
20-minute fit that nobody has run. Until someone does, the honest statement is
**"the inputs are verified complete; the output is unverified"**, not "the core
is reproducible".
