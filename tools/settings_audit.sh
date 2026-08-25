#!/usr/bin/env bash
# settings_audit.sh — prove the two fits ran under IDENTICAL project settings.
#
# The whole value of a paired fit is that settings are held constant while ONE
# thing changes. That has to be asserted in the output, not implied — especially
# here, where the canon tree's UNCOMMITTED NES.qsf (EDA netlist-writer settings
# + duplicate file assignments) is what made the stored Aug-21 numbers useless
# as a control in the first place. The same class of drift between A and B would
# silently invalidate the pair.
A=/home/struktured/projects/NES_MiSTer-boardtap
Bl=/home/struktured/projects/NES_MiSTer-baseline
fail=0

echo "=== SETTINGS EACH FIT RAN UNDER ==="
for f in NES.qsf files.qip rtl/mappers/mappers.qip NES.sdc; do
  ha=$(md5sum "$A/$f"  2>/dev/null | cut -c1-12)
  hb=$(md5sum "$Bl/$f" 2>/dev/null | cut -c1-12)
  if [ "$ha" = "$hb" ]; then mark="identical"
  elif [ "$f" = "files.qip" ]; then mark="differs (EXPECTED: the BoardTap.sv line)"
  else mark="*** DIFFERS — UNEXPECTED, PAIR IS NOT CONTROLLED ***"; fail=1; fi
  printf "  %-24s A=%s  B=%s  %s\n" "$f" "${ha:-MISSING}" "${hb:-MISSING}" "$mark"
done

echo
echo "=== SEED actually in each project file (read, not assumed) ==="
printf "  A: %s\n" "$(grep -E '^set_global_assignment -name SEED ' "$A/NES.qsf")"
printf "  B: %s\n" "$(grep -E '^set_global_assignment -name SEED ' "$Bl/NES.qsf")"
sa=$(grep -oP '(?<=-name SEED ).*' "$A/NES.qsf"); sb=$(grep -oP '(?<=-name SEED ).*' "$Bl/NES.qsf")
[ "$sa" = "$sb" ] || { echo "  *** SEEDS DIFFER — PAIR IS NOT CONTROLLED ***"; fail=1; }

echo
echo "=== the ONLY intended project-file difference ==="
diff "$Bl/files.qip" "$A/files.qip" | sed 's/^/  /' || true
n=$(diff "$Bl/files.qip" "$A/files.qip" | grep -c '^[<>]')
if [ "$n" = 1 ] && diff "$Bl/files.qip" "$A/files.qip" | grep -q 'BoardTap.sv'; then
  echo "  => exactly one line, and it is BoardTap.sv. Correct."
else
  echo "  *** expected exactly one BoardTap line, got $n changed lines ***"; fail=1
fi

echo
echo "=== neither fit inherits the canon tree's UNCOMMITTED settings ==="
if grep -q "EDA_SIMULATION_TOOL" "$A/NES.qsf" || grep -q "EDA_SIMULATION_TOOL" "$Bl/NES.qsf"; then
  echo "  *** a worktree picked up the canon EDA settings ***"; fail=1
else
  echo "  confirmed: no EDA netlist-writer settings in either — both are committed HEAD"
fi

echo
[ "$fail" = 0 ] && echo "SETTINGS AUDIT PASS: A and B differ in BoardTap and nothing else." \
                || echo "*** SETTINGS AUDIT FAIL — do not report the pair as controlled ***"
exit "$fail"
