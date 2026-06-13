#!/bin/sh
set -eu

cd "$(dirname "$0")"

chips="
CHIP.v
"

cycles="
2.76 2.77 2.78 2.79 2.8
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
