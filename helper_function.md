
push.ps1/push.sh 
===
#### run @ DSD_Final/
Windows
```terminal
./push.ps1 commit_message
```
Linux / macOS (not try yet)
```bash
bash push.sh commit_message
```
01_RTL/Makefile
===
### Currently only support putting verilog code in one file (ex.CHIP.v)
#### No longer need 01_rtl.f
##### run @ 01_RTL/
```bash
make run PATTERN=LFSR_HIST
```
trivial
```bash
make run_all
```
run all pattern

```bash
make run3
```
run the 3 graded pattern

```bash
env CHIP=*CHIP_FILENAME* make run_all
env CHIP=CHIP_2.v make run_all
```
if CHIP's FILENAME is not CHIP.v

run_all & run3 output at
```
rtl_summary_$(CHIP_filename)_$(SYN_CYCLE)_$(SIM_TIME)_$${pass or fail}.csv
```
including
```
pattern,result,sim_time,timing_violations,stall_total,stall_load_use,stall_mem,stall_mul,stall_ifetch,stall_dmem,stall_imem,cycle_count
```

02_SYN/syn_all_CHIP.sh
===
##### run @ 02_SYN

```bash
bash syn_all_CHIP.sh
```

In the file...
```shell
chips=(
  CHIP.v
  CHIP_2.v  
  CHIP_3.v
)
```
select which CHIP files to synthesis
```shell
cycles=(
  2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9
)
```
each CHIP file scan through these cycles.  
Total len(chips) * len(cycles) synthesis.
```shell
max_jobs="${MAX_JOBS:-10}"
```
at most MAX_JOBS running in background at the same time.  
Output at
```shell 
Netlist_${chip_filename}_${syn_cycle}
Report_${chip_filename}_${syn_cycle}
```
02_SYN/get_area_slack.sh
===
##### run @ 02_SYN
```shell 
bash get_area_slack.sh *report folder*
bash get_area_slack.sh Report_CHIP_b028792_2.5
```
grep area and slack.  
if MET time constrain, calculate 'estimated' 'relative' score
```
score = area*cycle time^3
```


03_RTL/Makefile
---
### Default Folder: ../02_SYN/Netlist is buggy, lazy to fix
#### No longer need 03_gate.f
##### run @ 03_GATE
```bash
FOLDER=../02_SYN/_${chip_filename}_${syn_cycle} make run PATTERN=LFSR_HIST
FOLDER=../02_SYN/_${chip_filename}_${syn_cycle} make run_all
FOLDER=../02_SYN/_${chip_filename}_${syn_cycle} make run3
FOLDER=../02_SYN/_CHIP_old_2.8 make run3
```
default use syn_cycle time for gate sim.

```bash
FOLDER=../02_SYN/_${chip_filename}_${syn_cycle} SIM_TIME=assigned_sim_time make run_all
FOLDER=../02_SYN/_CHIP_old_2.8 SIM_TIME=2.9 make run3
```
to assign different gate sim cycle time.  
run_all & run3 output at
```
gate_summary_$(CHIP_filename)_$(SYN_CYCLE)_$(SIM_TIME)_$${pass or fail}.csv
```
including
```
pattern,result,sim_time,timing_violations,stall_total,stall_load_use,stall_mem,stall_mul,stall_ifetch,stall_dmem,stall_imem,cycle_count
```


