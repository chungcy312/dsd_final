# Default target
all: 
	make run

PATTERN ?= QSort
PATTERNS ?= noHazard hasHazard BrPred Scaling compression compression_uncompressed QSort_uncompressed QSort Conv Conv_uncompressed Mul LFSR_HIST LFSR_HIST_short
PATTERNS3 ?= QSort Conv LFSR_HIST
VCS_WARN_OPTS ?= +warn=noTFIPC
CHIP ?= CHIP.v
FOLDER ?= Netlist
SIM_TIME ?= 3.0
SYN_CYCLE ?= $(lastword $(subst _, ,$(FOLDER)))
CHIP_BASE := $(basename $(notdir $(CHIP)))
NETLIST_FILE ?= ../02_SYN/$(FOLDER)/$(CHIP_BASE)_syn.v
SDF_FILE ?= ../02_SYN/$(FOLDER)/$(CHIP_BASE)_syn.sdf
SUMMARY_PREFIX ?= gate_summary_$(CHIP_BASE)_syn$(SYN_CYCLE)_sim$(SIM_TIME)
SUMMARY_TMP ?= $(SUMMARY_PREFIX)_running.csv
SUMMARY ?= $(SUMMARY_TMP)
GATE_FILES = ../00_TESTBED/testbench/Final_tb.v \
             ../00_MEMORY/slow_memory_random_latency.v \
             ../00_MEMORY/slow_memory.v \
             ../00_MEMORY/fast_memory.v \
             ../00_TESTBED/testbench/flush_inst_define.v \
             $(NETLIST_FILE) \
             -v /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/Verilog/tsmc13.v

# Gate simulation
run:
	vcs $(GATE_FILES) +define+$(PATTERN) +define+SDF +define+SDFFILE=\"$(SDF_FILE)\" +define+CYCLE=$(SIM_TIME) $(VCS_WARN_OPTS) -full64 -R +v2k -debug_access+all | tee vcs_$(PATTERN).log

clean:
	-rm novas*
	-rm ucli.key
	-rm simv
	-rm -rf csrc/
	-rm -rf *.fsdb
	-rm -rf nWaveLog/
	-rm -rf simv.daidir/

run_all:
	@rm -f $(SUMMARY); \
	echo "pattern,result,sim_time,timing_violations,timing_violations_after_reset,stall_total,stall_load_use,stall_mem,stall_mul,stall_ifetch,stall_dmem,stall_imem,cycle_count" > $(SUMMARY)
	@set -e; \
	overall=pass; \
	for pat in $(PATTERNS); do \
		echo "============================================================"; \
		echo "[GATE] Running $$pat with FOLDER=$(FOLDER), CHIP=$(CHIP), SIM_TIME=$(SIM_TIME)"; \
		echo "============================================================"; \
		$(MAKE) clean >/dev/null; \
		$(MAKE) run PATTERN=$$pat CHIP=$(CHIP) FOLDER=$(FOLDER) SIM_TIME=$(SIM_TIME); \
		if grep -q "CONGRATULATIONS" vcs_$$pat.log; then functional=PASS; \
		elif grep -q "FAIL" vcs_$$pat.log; then functional=FAIL; \
		else functional=UNKNOWN; fi; \
		time=$$(awk '/\$$finish at simulation time/ {t=$$NF} END {print t}' vcs_$$pat.log); \
		viol=$$(grep -c "Timing violation" vcs_$$pat.log || true); \
		eff_viol=$$(awk 'BEGIN{seen=0; after=0; total=0} /\[[0-9]+\] Reset done/{seen=1} /Timing violation/{total++; if(seen) after++} END{if(seen) print after+0; else print total+0}' vcs_$$pat.log); \
		if [ "$$functional" = "PASS" ] && [ "$$eff_viol" -gt 0 ]; then result=FAIL_TIMING; \
		else result=$$functional; fi; \
		if [ "$$result" = "FAIL" ] || [ "$$result" = "UNKNOWN" ]; then overall=fail; \
		elif [ "$$result" = "FAIL_TIMING" ] && [ "$$overall" = "pass" ]; then overall='fail(timing violation)'; fi; \
		stalls=$$(awk '/STALL_SUMMARY/ {for (i=1;i<=NF;i++) {split($$i,a,"="); v[a[1]]=a[2]}} END {printf "%s,%s,%s,%s,%s,%s,%s,%s", v["total"]+0, v["load_use"]+0, v["mem"]+0, v["mul"]+0, v["ifetch"]+0, v["dmem"]+0, v["imem"]+0, v["cycles"]+0}' vcs_$$pat.log); \
		printf "%s,%s,%s,%s,%s,%s\n" "$$pat" "$$result" "$$time" "$$viol" "$$eff_viol" "$$stalls" | tee -a $(SUMMARY); \
	done; \
	final_summary="$(SUMMARY_PREFIX)_$${overall}.csv"; \
	mv $(SUMMARY) "$$final_summary"; \
	echo "============================================================"; \
	echo "[GATE] Summary written to $$final_summary"; \
	cat "$$final_summary"

run3:
	@rm -f $(SUMMARY); \
	echo "pattern,result,sim_time,timing_violations,timing_violations_after_reset,stall_total,stall_load_use,stall_mem,stall_mul,stall_ifetch,stall_dmem,stall_imem,cycle_count" > $(SUMMARY)
	@set -e; \
	overall=pass; \
	for pat in $(PATTERNS3); do \
		echo "============================================================"; \
		echo "[GATE] Running $$pat with FOLDER=$(FOLDER), CHIP=$(CHIP), SIM_TIME=$(SIM_TIME)"; \
		echo "============================================================"; \
		$(MAKE) clean >/dev/null; \
		$(MAKE) run PATTERN=$$pat CHIP=$(CHIP) FOLDER=$(FOLDER) SIM_TIME=$(SIM_TIME); \
		if grep -q "CONGRATULATIONS" vcs_$$pat.log; then functional=PASS; \
		elif grep -q "FAIL" vcs_$$pat.log; then functional=FAIL; \
		else functional=UNKNOWN; fi; \
		time=$$(awk '/\$$finish at simulation time/ {t=$$NF} END {print t}' vcs_$$pat.log); \
		viol=$$(grep -c "Timing violation" vcs_$$pat.log || true); \
		eff_viol=$$(awk 'BEGIN{seen=0; after=0; total=0} /\[[0-9]+\] Reset done/{seen=1} /Timing violation/{total++; if(seen) after++} END{if(seen) print after+0; else print total+0}' vcs_$$pat.log); \
		if [ "$$functional" = "PASS" ] && [ "$$eff_viol" -gt 0 ]; then result=FAIL_TIMING; \
		else result=$$functional; fi; \
		if [ "$$result" = "FAIL" ] || [ "$$result" = "UNKNOWN" ]; then overall=fail; \
		elif [ "$$result" = "FAIL_TIMING" ] && [ "$$overall" = "pass" ]; then overall='fail(timing violation)'; fi; \
		stalls=$$(awk '/STALL_SUMMARY/ {for (i=1;i<=NF;i++) {split($$i,a,"="); v[a[1]]=a[2]}} END {printf "%s,%s,%s,%s,%s,%s,%s,%s", v["total"]+0, v["load_use"]+0, v["mem"]+0, v["mul"]+0, v["ifetch"]+0, v["dmem"]+0, v["imem"]+0, v["cycles"]+0}' vcs_$$pat.log); \
		printf "%s,%s,%s,%s,%s,%s\n" "$$pat" "$$result" "$$time" "$$viol" "$$eff_viol" "$$stalls" | tee -a $(SUMMARY); \
	done; \
	final_summary="$(SUMMARY_PREFIX)_$${overall}.csv"; \
	mv $(SUMMARY) "$$final_summary"; \
	echo "============================================================"; \
	echo "[GATE] Summary written to $$final_summary"; \
	cat "$$final_summary"
	
help:
	@echo "Usage:"
	@echo "make run PATTERN=QSort: run one gate simulation pattern"
	@echo "make run_all: run all score/check patterns in PATTERNS"
	@echo "make run3: run QSort, Conv, and LFSR_HIST"
	@echo "FOLDER=Netlist_CHIP_xxxxx_2.9 CHIP=CHIP_xxxxx.v SIM_TIME=3.0 make run_all"
	@echo "SUMMARY_PREFIX=name can override the summary output prefix"

.PHONY: all run clean run_all run3
