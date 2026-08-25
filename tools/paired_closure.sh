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

# ---------------------------------------------------------------- the gate
# ⚠ THE PREVIOUS THRESHOLD (load > 8) WAS A LATENT BUG AND WOULD NEVER HAVE
# OPENED. blackmage runs 24 cores; the e1 primary arm alone holds ~14 workers
# until ~midnight, so post-guard load settles around 14-16 -- still far above 8.
# The gate would have refused all afternoon, and because a refusal is silent by
# design, the screen would simply never have run. It would also have refused a
# MANUAL GO, so this was not merely a polling bug.
#
# Gate on FREE CAPACITY instead: load below (nproc - HEADROOM). Post-guard
# (~15) passes; a genuinely saturated box (23+) still fails.
HEADROOM="${HEADROOM:-6}"

# All inputs injectable, so the ADMIT path can be proven without waiting for
# the guard arm to actually exit (see --selftest).
probe_guard()  { [ -n "${TEST_GUARD:-}" ] && { echo "$TEST_GUARD"; return; }
                 systemctl --user is-active --quiet drm-h16-guard.service \
                   2>/dev/null && echo active || echo inactive; }
probe_load()   { [ -n "${TEST_LOAD:-}"  ] && { echo "$TEST_LOAD";  return; }
                 cut -d' ' -f1 /proc/loadavg; }
probe_nproc()  { [ -n "${TEST_NPROC:-}" ] && { echo "$TEST_NPROC"; return; }
                 nproc; }

# gate_check -> 0 admit, 6 guard still up, 5 no capacity. Echoes the reason.
gate_check() {
  local g l n lim
  g=$(probe_guard); l=$(probe_load); n=$(probe_nproc)
  lim=$(( n - HEADROOM ))
  if [ "$g" = "active" ]; then
    echo "drm-h16-guard.service ACTIVE — its workers are not free yet"; return 6
  fi
  if awk -v l="$l" -v m="$lim" 'BEGIN{exit !(l>=m)}'; then
    echo "load $l >= $lim (nproc $n - headroom $HEADROOM) — no free capacity"; return 5
  fi
  echo "guard inactive, load $l < $lim (nproc $n - headroom $HEADROOM)"; return 0
}

# --selftest: prove BOTH directions, same standard as the mssh mutant. A gate
# that has only been shown to refuse is half-tested -- that is exactly how the
# load>8 bug survived.
if [ "${1:-}" = "--selftest" ]; then
  fails=0
  check() { # name expected_rc env...
    local name="$1" want="$2"; shift 2
    local out rc
    out=$(env "$@" bash -c "source '$0' --source-only; gate_check" 2>&1); rc=$?
    if [ "$rc" = "$want" ]; then printf "  PASS %-46s rc=%s\n" "$name" "$rc"
    else printf "  FAIL %-46s rc=%s want=%s (%s)\n" "$name" "$rc" "$want" "$out"; fails=1; fi
  }
  echo "=== gate truth table ==="
  check "guard ACTIVE, load 23.6 (reality now)"      6 TEST_GUARD=active   TEST_LOAD=23.6 TEST_NPROC=24
  check "guard ACTIVE, idle box (guard is primary)"  6 TEST_GUARD=active   TEST_LOAD=2.0  TEST_NPROC=24
  check "POST-GUARD load 15 -- MUST ADMIT"           0 TEST_GUARD=inactive TEST_LOAD=15.0 TEST_NPROC=24
  check "post-guard load 14 -- MUST ADMIT"           0 TEST_GUARD=inactive TEST_LOAD=14.0 TEST_NPROC=24
  check "post-guard load 17.9 (just under limit)"    0 TEST_GUARD=inactive TEST_LOAD=17.9 TEST_NPROC=24
  check "load 18.0 (at limit) refuses"               5 TEST_GUARD=inactive TEST_LOAD=18.0 TEST_NPROC=24
  check "saturated by something else, load 23"       5 TEST_GUARD=inactive TEST_LOAD=23.0 TEST_NPROC=24
  echo; [ "$fails" = 0 ] && echo "GATE OK: refuses when it must, and ADMITS the post-guard state." \
                        || echo "*** GATE BROKEN"
  exit "$fails"
fi
[ "${1:-}" = "--source-only" ] && return 0 2>/dev/null

# ---- sticky refusal: silence is right for a gate that will open, and
# dangerous for one that never will. Say something after 3 in a row.
STATE=/tmp/.boardtap_gate_refusals
reason=$(gate_check); grc=$?
if [ "$grc" != 0 ]; then
  n=$(( $(cat "$STATE" 2>/dev/null || echo 0) + 1 ))
  echo "$n" > "$STATE"
  if [ "$n" -ge 3 ] && [ $(( n % 3 )) = 0 ]; then
    echo "NOTICE: closure screen has now refused $n times in a row: $reason" >&2
  fi
  die "REFUSING: $reason" "$grc"
fi
: > "$STATE"

[ "${GO:-0}" = "1" ] || die \
"REFUSING: no GO. The gate is open ($reason) but this runs ~40 min of heavy fit
  on blackmage. Re-run as: GO=1 $0" 7

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
