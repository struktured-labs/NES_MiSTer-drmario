#!/usr/bin/env bash
# theta400 champion-candidate ship compile wrapper (phase 2).
# Runs the canonical ship pipeline (seed-pinned, clean-db full flow) with a
# firmware-integrity guard on both sides of the compile window.
set -uo pipefail
FORK=/home/struktured/projects/NES_MiSTer-winner
SHIP=/home/struktured/projects/dr-mario-main-wt/experiments/rtl_chain/ship_build.sh
WANT_FW=f78f1e9376405dc996404f68dfa9dfb8

cd "$FORK"
pre=$(md5sum copro_rom.hex | cut -d' ' -f1)
if [ "$pre" != "$WANT_FW" ]; then
  echo "ABORT: copro_rom.hex md5 $pre != expected $WANT_FW" >&2
  exit 64
fi
echo "fw-guard PRE : copro_rom.hex $pre OK"

"$SHIP" 13 theta400
rc=$?

post=$(md5sum copro_rom.hex | cut -d' ' -f1)
echo "fw-guard POST: copro_rom.hex $post $( [ "$post" = "$WANT_FW" ] && echo OK || echo CHANGED-DURING-BUILD )"
[ "$post" = "$WANT_FW" ] || rc=64
echo "WRAPPER EXIT rc=$rc"
exit "$rc"
