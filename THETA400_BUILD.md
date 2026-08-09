# NES_theta400_20260809.rbf — MiSTer core, θ400 champion-candidate firmware

STAGED ONLY. Nothing in this directory has touched hardware. No scp, no `load_core`,
no soak was started; the currently-soaking core on the MiSTer was not disturbed.

## Artifact

| item | value |
|---|---|
| rbf | `NES_theta400_20260809.rbf` — md5 `de7dea35a9fa03a622cccc8068bd935e`, 3,565,528 B |
| sof | `NES.sof` — md5 see `sha` below (same compile, same db) |
| firmware in the image | `copro_rom.hex` md5 `f78f1e9376405dc996404f68dfa9dfb8` (th400) |
| RTL commit | `ff1db5aaaf3cce1350a570266a13042fa99d4844` (`claude/winner-single-copro`, NES_MiSTer-winner) |
| LeafEval.sv | md5 `5f06209642d1547e99cea077523662dc` |
| CoproDrMario.sv | md5 `da3e5e808762f760ddc46c23c88dc96e` |
| fitter seed | 13 (pinned; exactly one SEED line, archived in `NES.qsf.used`) |
| Quartus | 23.1std.1 Build 993 Lite, device 5CSEBA6U23I7 |

## Timing / area verdict (fit_verdict.sh, all three criteria)

    Fitter status : Successful - Sun Aug  9 09:25:37 2026
    ALMs          : 37575 / 41910  (4335 free)   PASS   (floor 1500 free)
    copro slack   : 0.391 ns (bar +0.10)         PASS
    pll_hdmi      : 0.051 ns (baseline -0.012)   PASS
    VERDICT: SHIP AS-IS

For scale: the shipped Combo Stomper closed at +0.156 ns and the tier-3 seed sweep of
2026-08-05 could only reach +0.051 ns in 6 seeds (5 outright misses). +0.391 ns is the
widest copro-domain margin this design has had.

## The compile was REAL, not an update_mif no-op

`quartus_cdb --update_mif` is a silent no-op for a `$readmemh`-initialised ROM, and
Quartus smart recompilation can degenerate a full `--flow compile` into the same no-op
(memory `quartus-update-mif-readmemh`: three differently-labelled arms once produced ONE
identical rbf). So the flag/exit status proves nothing. What was asserted instead:

1. `db/` and `incremental_db/` deleted before the flow (ship_build.sh does this).
2. All four stages ran, from the flow report's own elapsed table:
   Analysis & Synthesis 00:03:54, Fitter 00:16:57, Assembler 00:00:19,
   Timing Analyzer 00:00:14, total 00:21:24. The only "Skipped" line in the whole log is
   `Power Analyzer due to FLOW_ENABLE_POWER_ANALYZER` — no stage skip.
3. Report freshness gate (fit_verdict.sh) passed and printed real numbers; the same gate
   returned `VERDICT: UNKNOWN` for the previous, dead attempt whose reports predated the
   firmware — i.e. the freshness check is live and has been seen to FIRE.

## PROOF that θ400 firmware is IN the built image (not merely in the recipe)

Two independent links, both content-level, both against the compiled database that
`quartus_asm` serialised into this exact `NES.sof`/`NES.rbf`:

**A. Synthesis link.** `db/NES.ram0_CoproDrMario_15c5156a.hdl.mif` (emitted by
Analysis & Synthesis at 09:05 from `$readmemh`, DATA_RADIX=BIN) == `copro_rom.hex`:
**16384/16384 bytes**, 0 diff.

**B. Post-fit image link.** `quartus_eda --simulation --format=verilog` re-serialised the
post-fit netlist (`NES.vo`) from the same db. The firmware occupies 16 one-bit M20K slices
under `emu|nes|multi_mapper|copro2|rom_rtl_0|auto_generated|ram_block1a*`; their `mem_initN`
parameters were reassembled into the 16 KB byte image by
`NES_MiSTer-winner/tools_verify_fw_in_image.py`:

    ROM slices found : 16 in 2 groups
    bytes recovered  : 16384/16384 (2 x 8192-byte halves)
    EXPECTED th400/copro_rom.hex : MATCH 16384/16384 bytes (low-half=group0;
                                   the other half-order differs in 12062 bytes)
    CONTROL  th150/copro_rom.hex : DIFFERS, 2 bytes  (7525: 96 vs image 90; 7531: 00 vs 01)
    CONTROL  th4000/copro_rom.hex: DIFFERS, 2 bytes  (7525: a0 vs image 90; 7531: 0f vs 01)
    CONTROL  copro_rom.hex.preship.bak (shipped Stomper fw f4b6dfbf): DIFFERS, 5834 bytes
    IMAGE-PROOF PASS

The controls are the gate, not the match (house rule: test the defect). th150 and th4000
differ from th400 in exactly the two bytes of the 16-bit θ dose constant, so an extractor
that could not tell them apart could not tell any two firmwares apart. Read straight out of
the image: `rom[7525]=0x90`, `rom[7531]=0x01` → **θ = 0x0190 = 400**. The half-order is
also unambiguous (the wrong order mismatches in 12,062 bytes), so a swapped-half
reconstruction cannot be waved through.

The proof script itself was mutation-tested (a gate that has never been seen to fail is
not a gate): a 1-bit-flipped th400 hex as EXPECTED → `MISMATCH ... 1/16384 bytes, addr 1234
hex 60 image 61`, exit 1; th400 passed as its own CONTROL → `IDENTICAL -- CONTROL FAILED`,
exit 1; the real invocation → exit 0.

Effective flag set follows transitively: the image bytes ARE th400's `copro_rom.hex`, and
phase 1 re-ran `build_dbgpub.py` from `RECIPE.json` (DRSTRAND=20 DRCHAIN=180 DRCOPRO_ARM=1
DRFIX=1 DRCOPRO_TUCKBFS=1 DRCOPRO_TUCKBFS_TIER3=1 DRCOPRO_TUCKV3_FIXSLOT=1
DRCOPRO_TUCKV3_THETA=400) reproducing those bytes byte-exactly. This closes the
`dr-mario-tier3-hash-confound` hole: the flag set is verified on the BUILT artifact.

`build_id.v` carries only `BUILD_DATE "260809"` (a date stamp, no per-build entropy), so
same-day rebuilds are not decoupled from their recipe by the stamp.

## Cross-variant distinctness (N labels must give N hashes)

    de7dea35a9fa03a622cccc8068bd935e  NES_theta400_20260809.rbf          <- this build
    caa5b5c669017dac7e14e82b8e94a722  NES_stomper180s20t3_20260805_seed13.rbf (same SEED 13)
    1da3d05756f32e98c0e3cbcec034111a  ..._seed7_TIMINGFAIL.rbf
    529ada5d3a41e271dd50241fdd364e8c  ..._seed9_TIMINGFAIL.rbf
    beb1104b2d34196a2c7a19c58cbe3d3d  ..._seed11_TIMINGFAIL.rbf
    5c2a3be7d358e63463b567b922402acc  ..._seed15_TIMINGFAIL.rbf
    26b004aba3a3dfc87b8b5d02d0a6d1e8  ..._seed17_TIMINGFAIL.rbf
    71d2de37b1fbcabbb92701fc4094f833  shipped Combo Stomper (stomper180-seed2)
    f7d3382a422abde5559f612d838c4c94  QUARANTINE_combostomper-seed2 (the update_mif collision)
    22c11377648893a963fb8fb091a202dc  upstream releases/NES_20260603.rbf

Unique against all 9. ship_build.sh's own collision check also reported unique across the
3 archived ship builds. Note the same-seed Aug-5 build (caa5b5c6) differs from this one,
i.e. changing only the firmware hex demonstrably moves the bitstream.

## Bit-exactness gates run against THIS build's RTL

`experiments/bitexact_gate` (dr-mario-qa-wt @ a97bcc1), gated on
`NES_MiSTer-winner/rtl/mappers/LeafEval.sv` md5 `5f062096` — the file compiled here:

| level | result |
|---|---|
| selfcheck | PASS, 18/18 mutants killed, o4 map (2,3,0,1) recovered on 267 link-free node cases |
| rtl PHASE1 LEAF | 948/948 |
| rtl PHASE2 NODE | 4238/4494 — FAILS BY DESIGN on a link-aware .sv (compact-gravity oracle); all 256 mismatches are `sco`-only, `legal/cells/vir/imm/win` agree on every case |
| rtl PHASE3 DELTA | 4494/4494 (743 clear-fallbacks verified) |
| linknode | PASS — 7282 cases, colour+virus+LINK planes and chain depth, 9/9 mutants killed, 0 bypass collisions latched |
| candidate | PASS 948 cases x 23 variants |
| pairs | PASS 3147 no-clear pairs x 23 variants |

Side effect of this phase: stock `gate.py selfcheck` was RED (o4 recovery could not match
the link-aware 436-case node corpus with the compact `_expand_core` oracle). Diagnosed here,
fixed by the exactness-gate lane in `fe8f4a4` (link-free filter, skip count printed,
hard-errors under 100 survivors). All numbers above are from the fixed gate.

## Files

    NES_theta400_20260809.rbf   the deliverable
    NES.sof                     same compile (JTAG path)
    copro_rom.hex               the firmware that is provably inside the image
    NES.fit.summary / NES.sta.summary   the reports the verdict was read from
    NES.qsf.used                the exact project configuration (one SEED line, = 13)
    manifest.json / verdict.txt ship_build.sh output

Rebuild: re-pin SEED 13 in NES.qsf, `rm -rf db incremental_db`, full flow; expect the same
slack. Re-verify with `tools_verify_fw_in_image.py` before trusting any rebuilt image.

## NOT done here (deliberately)

Hardware install, `load_core`, soak start, and the ≥3-board silicon fingerprint all remain
for the owner-guided session (busy-brick risk, memory `dr-mario-busy-brick`). Emulator
cart-level QA (Mesen) and the first cart-executed-tuck proof are the next phase.
