#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chips=(
  # CHIP.v
  CHIP_db95602_nb_i32d32.v
  CHIP_db95602_nb_i32d16.v 
)

cycles=(
  2.6 2.62 2.64 2.66 2.52 2.56 2.58 
)

max_jobs="${MAX_JOBS:-10}"

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
    (
      set +e
      env CHIP="$chip" CYCLE_TIME="$cycle" bash 02_syn > "$log" 2>&1
      status=$?
      echo "[SYN][DONE] CHIP=${chip} CYCLE_TIME=${cycle} status=${status} log=${log}"
      exit "$status"
    ) &
  done
done

wait
echo "[SYN] All synthesis jobs finished."
