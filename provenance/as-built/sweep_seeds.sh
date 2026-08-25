#!/usr/bin/env bash
# Sequential SEED sweep for the tier-3 candidate's HDMI PLL timing-closure miss.
# Guardrails per team-lead (2026-08-05):
#   - a positive-but-thin slack is CLOSED-BUT-MARGINAL, not a stop condition by itself;
#     keep sweeping toward s20b's own +0.156ns bar.
#   - stop and report a decision (don't seed-hunt indefinitely) once total MISSES
#     across the whole campaign (including seed 7 and seed 9, already run) reaches 5.
set -uo pipefail
cd /home/struktured/projects/NES_MiSTer-winner

QSF=NES.qsf
TABLE=SEED_SWEEP_TABLE.csv
SUCCESS_THRESHOLD=0.10   # comfortable margin, ~2/3 of s20b's own +0.156 bar
TOTAL_MISSES=2           # seed 7 (-0.074) and seed 9 (-0.020), already run and recorded

for SEED in 11 13 15 17; do
  echo "SEED $SEED: launching fit"
  sed -i "s/^set_global_assignment -name SEED .*/set_global_assignment -name SEED $SEED/" "$QSF"
  rm -rf db incremental_db
  ./run_fit.sh > "fit_s20t3_seed${SEED}.log" 2>&1
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "SEED $SEED: FIT PROCESS FAILED rc=$RC"
    echo "$SEED,ERROR,ERROR,FIT_FAILED" >> "$TABLE"
    continue
  fi

  READ=$(awk '/Timing Analyzer Summary/{f=1} f && /Type  :/{print; getline; print; getline; print; exit}' output_files/NES.sta.summary)
  CRIT_TYPE=$(echo "$READ" | sed -n '1p')
  SLACK=$(echo "$READ" | sed -n '2p' | awk -F: '{print $2}' | tr -d ' ')
  TNS=$(echo "$READ" | sed -n '3p' | awk -F: '{print $2}' | tr -d ' ')

  cp output_files/NES.rbf "NES_stomper180s20t3_20260805_seed${SEED}.rbf"
  HASH=$(md5sum "NES_stomper180s20t3_20260805_seed${SEED}.rbf" | awk '{print $1}')

  IS_POS=$(awk -v s="$SLACK" 'BEGIN{print (s+0>0)?1:0}')
  if [ "$IS_POS" -eq 1 ]; then
    IS_COMFORTABLE=$(awk -v s="$SLACK" -v t="$SUCCESS_THRESHOLD" 'BEGIN{print (s+0>=t)?1:0}')
    if [ "$IS_COMFORTABLE" -eq 1 ]; then
      mv "NES_stomper180s20t3_20260805_seed${SEED}.rbf" "NES_stomper180s20t3_20260805.rbf"
      echo "$SEED,$SLACK,$TNS,CLOSED" >> "$TABLE"
      echo "SEED $SEED RESULT: CLOSED slack=${SLACK}ns hash=$HASH path=[$CRIT_TYPE] -- STOPPING SWEEP, comfortable margin"
      break
    else
      echo "$SEED,$SLACK,$TNS,CLOSED-BUT-MARGINAL" >> "$TABLE"
      echo "SEED $SEED RESULT: CLOSED-BUT-MARGINAL slack=${SLACK}ns hash=$HASH path=[$CRIT_TYPE] -- continuing sweep for headroom"
    fi
  else
    mv "NES_stomper180s20t3_20260805_seed${SEED}.rbf" "NES_stomper180s20t3_20260805_seed${SEED}_TIMINGFAIL.rbf"
    TOTAL_MISSES=$((TOTAL_MISSES+1))
    echo "$SEED,$SLACK,$TNS,MISS" >> "$TABLE"
    echo "SEED $SEED RESULT: MISS slack=${SLACK}ns path=[$CRIT_TYPE] total_misses=$TOTAL_MISSES"
    if [ "$TOTAL_MISSES" -ge 5 ]; then
      echo "SWEEP STOPPED: $TOTAL_MISSES total misses -- recommend decision (tier-2 fallback vs RTL/timing-constraint look), not further seed-hunting"
      break
    fi
  fi
done

echo "SWEEP LOOP DONE"
cat "$TABLE"
