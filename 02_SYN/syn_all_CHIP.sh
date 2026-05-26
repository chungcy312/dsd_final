#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chips=(
  CHIP.v
  CHIP_6636cb2.v
  CHIP_b028792.v
  CHIP_c2ad7a8.v
  CHIP_cccb5c4.v
  CHIP_db95602.v
)

cycles=(
  2.3 2.4 2.5 2.6 2.7 2.8 2.9
  3.0 3.1 3.2 3.3 3.4 3.5
)

max_jobs="${MAX_JOBS:-5}"

mkdir -p logs

wait_for_slot() {
  while [ "$(jobs -pr | wc -l)" -ge "$max_jobs" ]; do
    sleep 5
  done
}

for chip in "${chips[@]}"; do
  chip_base="${chip%.v}"
  for cycle in "${cycles[@]}"; do
    wait_for_slot
    log="logs/syn_${chip_base}_${cycle}.log"
    echo "[SYN] CHIP=${chip} CYCLE_TIME=${cycle} -> ${log}"
    nohup env CHIP="$chip" CYCLE_TIME="$cycle" bash 02_syn > "$log" 2>&1 &
  done
done

wait
echo "[SYN] All synthesis jobs finished."
