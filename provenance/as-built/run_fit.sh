#!/usr/bin/env bash
# Winner single-copro fit launcher (provenance build).
# Detached: nice 10, NUM_PARALLEL_PROCESSORS 4 (set in NES.qsf). Revision NES, top sys_top.
set -euo pipefail
cd /home/struktured/projects/NES_MiSTer-winner
QSH=/home/struktured/intelFPGA_lite/23.1std/quartus/bin/quartus_sh
echo "START $(date -Is)  host=$(hostname)  load=$(cut -d' ' -f1-3 /proc/loadavg)"
"$QSH" --flow compile NES
echo "END $(date -Is)  exit=$?"
