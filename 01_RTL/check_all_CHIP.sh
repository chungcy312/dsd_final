#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# nohup env CHIP=CHIP.v make run_all > output1.log 2>&1 &
# nohup env CHIP=CHIP_6636cb2.v make run_all > output2.log 2>&1 &
# nohup env CHIP=CHIP_b028792.v make run_all > output3.log 2>&1 &
# nohup env CHIP=CHIP_c2ad7a8.v make run_all > output4.log 2>&1 &
# nohup env CHIP=CHIP_cccb5c4.v make run_all > output5.log 2>&1 &
# nohup env CHIP=CHIP_db95602.v make run_all > output6.log 2>&1 &

# CHIP=CHIP.v make run_all
CHIP=CHIP_6636cb2.v make run_all

CHIP=CHIP_6636cb2_nb.v make run_all
CHIP=CHIP_b028792_nb.v make run_all
CHIP=CHIP_c2ad7a8_nb.v make run_all
CHIP=CHIP_cccb5c4_nb.v make run_all
CHIP=CHIP_db95602_nb.v make run_all

CHIP=CHIP_b028792.v make run_all
CHIP=CHIP_c2ad7a8.v make run_all
CHIP=CHIP_cccb5c4.v make run_all
CHIP=CHIP_db95602.v make run_all

# CHIP=CHIP_nb.v make run_all