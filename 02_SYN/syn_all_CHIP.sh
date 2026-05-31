#!/bin/sh
set -eu

cd "$(dirname "$0")"

chips="
CHIP_d16.v
"

cycles="
2.66 2.68 2.7 2.72 2.6 2.62 2.64 
"

max_jobs="${MAX_JOBS:-4}"

mkdir -p logs

wait_for_slot() {
  while [ "$(jobs -p | wc -l)" -ge "$max_jobs" ]; do
    sleep 5
  done
}

for chip in $chips; do
  chip_base="${chip%.v}"
  for cycle in $cycles; do
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
