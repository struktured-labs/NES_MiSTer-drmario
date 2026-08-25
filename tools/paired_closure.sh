#!/usr/bin/env bash
# paired_closure.sh — the two fits that decide BoardTap, run as a CONTROLLED PAIR.
#
#   fit A: HEAD + BoardTap   (~/projects/NES_MiSTer-boardtap)
#   fit B: HEAD, no BoardTap (~/projects/NES_MiSTer-baseline, detached at the
#                             exact parent commit 08f2343)
# Same seed, same settings, same box, back to back. ~40 min total.
#
# WHY BOTH. The only pre-existing reference is SEED_SWEEP_TABLE.csv from the
# older stomper180s20t3 campaign, AND the canon tree's uncommitted NES.qsf adds
# EDA netlist-writer settings that committed HEAD does not have. So comparing a
# HEAD+feature fit against those numbers would move two variables at once. The
# paired baseline is the control.
#
# ⚠ REQUIRES AN EXPLICIT GO. This box (blackmage) carries the champion trial and
# the guard arm finishing is the EVENT that frees cores -- not any instantaneous
# load reading, which stays high from the trial's other 14 workers either way.
# So this never starts itself: GO=1 must be passed by a human decision.
set -uo pipefail

QSH="$HOME/intelFPGA_lite/23.1std/quartus/bin/quartus_sh"
SEED="${SEED:-13}"
A=/home/struktured/projects/NES_MiSTer-boardtap
Bl=/home/struktured/projects/NES_MiSTer-baseline

die() { printf '%s\n' "$1" >&2; exit "${2:-1}"; }

[ "${GO:-0}" = "1" ] || die \
"REFUSING: no GO. This runs ~40 min of heavy fit on blackmage, which carries the
  champion trial. The guard arm finishing is the event that frees cores, not the
  load number. Re-run as: GO=1 $0" 7

if [ "${FORCE:-0}" != "1" ] \
   && systemctl --user is-active --quiet drm-h16-guard.service 2>/dev/null; then
  die "REFUSING: drm-h16-guard.service is still ACTIVE — its 4 workers are not free.
  (belt-and-braces; FORCE=1 to override if you know it is done)" 6
fi

[ -x "$QSH" ] || die "no quartus_sh at $QSH" 2
[ -d "$Bl" ]  || die "baseline worktree missing: $Bl" 3

run_fit() {   # $1 = worktree, $2 = label
  local d="$1" label="$2"
  cd "$d" || return 1
  sed -i "s/^set_global_assignment -name SEED .*/set_global_assignment -name SEED $SEED/" NES.qsf
  echo "== $label: START $(date -Is)  (seed $SEED, $d)"
  nice -n 19 "$QSH" --flow compile NES > "closure_${label}.log" 2>&1
  echo "== $label: END   $(date -Is)"
}

echo "### PAIRED CLOSURE SCREEN — seed $SEED — $(date -Is)"
run_fit "$A"  "boardtap"
run_fit "$Bl" "baseline"

echo
python3 "$A/tools/fit_report.py" "FIT A — HEAD + BoardTap (seed $SEED)" \
  "$A/output_files/NES.sta.rpt" "$A/output_files/NES.fit.summary"
echo
python3 "$A/tools/fit_report.py" "FIT B — HEAD without BoardTap, CONTROL (seed $SEED)" \
  "$Bl/output_files/NES.sta.rpt" "$Bl/output_files/NES.fit.summary"
echo
echo "Reference only (older revision, NOT a control): seed 13 closed at +0.051 in"
echo "SEED_SWEEP_TABLE.csv; the Aug-21 canon build bound on clk85 at +0.165."
