#!/usr/bin/env bash
# closure_screen.sh — the ONE Quartus fit that decides whether BoardTap can ship.
#
# It answers exactly one question: with BoardTap in the design, does the core
# still close timing at 90% ALM utilisation? Nothing else. No .rbf is deployed,
# the canon worktree is never touched, and this runs in the BRANCH worktree.
#
# ⚠ THIS BOX IS blackmage, which carries the champion trial. A Quartus fit is
# ~18-20 min of heavy multi-core work, so the script REFUSES to start while the
# box is loaded rather than trusting whoever runs it to check. Override only if
# you know the trial is done: FORCE=1.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

SEED="${SEED:-13}"          # seed 13 is the one the baseline sweep closed on
MAXLOAD="${MAXLOAD:-8}"     # 4 freed workers + headroom
QSH="$HOME/intelFPGA_lite/23.1std/quartus/bin/quartus_sh"

[ -x "$QSH" ] || { echo "no quartus_sh at $QSH" >&2; exit 2; }
[ "$(basename "$HERE")" = "NES_MiSTer-boardtap" ] || {
  echo "REFUSING: not in the boardtap worktree (got $HERE)" >&2; exit 3; }

# ★ Gate on the ACTUAL condition, not a wall-clock guess at when it happens:
# drm-h16-guard.service is the arm that holds the 4 workers we are waiting on.
# Read-only check; this script never touches any drm-h16* unit.
if [ "${FORCE:-0}" != "1" ] \
   && systemctl --user is-active --quiet drm-h16-guard.service 2>/dev/null; then
  echo "REFUSING: drm-h16-guard.service is still ACTIVE — its 4 workers are not free yet." >&2
  echo "  That arm, not the clock, is what releases the cores. Waiting." >&2
  exit 6
fi

load=$(cut -d' ' -f1 /proc/loadavg)
if [ "${FORCE:-0}" != "1" ] && \
   awk -v l="$load" -v m="$MAXLOAD" 'BEGIN{exit !(l>m)}'; then
  echo "REFUSING: load $load > $MAXLOAD — blackmage is still busy." >&2
  echo "  The champion trial owns this box; a fit here would slow its critical path." >&2
  echo "  Wait for the H16 guard arm to free cores, or FORCE=1 if the trial is done." >&2
  exit 4
fi

sed -i "s/^set_global_assignment -name SEED .*/set_global_assignment -name SEED $SEED/" NES.qsf
grep -q "BoardTap.sv" files.qip || { echo "BoardTap not in files.qip" >&2; exit 5; }

echo "== closure screen: seed $SEED, worktree $HERE, load $load"
echo "== START $(date -Is)"
nice -n 19 "$QSH" --flow compile NES > closure_seed${SEED}.log 2>&1 || true
echo "== END   $(date -Is)"

echo
echo "=== SETUP SUMMARY (all clocks must be >= 0) ==="
awk '/; Setup Summary/,/^\+---.*\+$/' output_files/NES.sta.rpt 2>/dev/null | head -16
echo
echo "=== UTILISATION (baseline was 37,664 / 41,910 = 90%) ==="
grep -E "Logic utilization|Total RAM Blocks|Total registers" output_files/NES.fit.summary 2>/dev/null
echo
echo "=== BASELINE for comparison (SEED_SWEEP_TABLE.csv, older revision — see caveat) ==="
echo "  seed 13 was the only closer: slack +0.051, TNS 0.000"
echo "  binding clock in the Aug-21 build: emu|pll|counter[0]|divclk (clk85) at +0.165"
