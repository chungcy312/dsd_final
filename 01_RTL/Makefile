# Default target
all: 
	make run

PATTERN ?= LFSR_HIST
PATTERNS ?= noHazard hasHazard BrPred Scaling compression compression_uncompressed QSort_uncompressed QSort Conv Conv_uncompressed Mul LFSR_HIST LFSR_HIST_short
PATTERNS3 ?= QSort_uncompressed Conv LFSR_HIST
DEFINES ?=
CHIP ?= CHIP.v
CHIP_BASE := $(basename $(notdir $(CHIP)))
RUN_ID := $(CHIP_BASE)_$(PATTERN)
BUILD_DIR := build_$(RUN_ID)
SIMV := $(BUILD_DIR)/simv
LOG := vcs_$(RUN_ID).log
SUMMARY_PREFIX ?= rtl_summary_$(CHIP_BASE)
SUMMARY_TMP ?= $(SUMMARY_PREFIX)_running.csv
SUMMARY ?= $(SUMMARY_TMP)
RTL_FILES = ../00_TESTBED/testbench/Final_tb.v \
            ../00_MEMORY/slow_memory_random_latency.v \
            ../00_TESTBED/testbench/flush_inst_define.v \
            $(CHIP)

# RTL simulation
run:
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	vcs $(RTL_FILES) +define+$(PATTERN) $(DEFINES) -full64 -R +v2k -debug_access+all -Mdir=$(BUILD_DIR)/csrc -o $(SIMV) | tee $(LOG)

clean:
	-rm novas*
	-rm ucli.key
	-rm simv
	-rm -rf build_$(CHIP_BASE)_$(PATTERN)/
	-rm -rf csrc/
	-rm -rf *.fsdb
	-rm -rf nWaveLog/
	-rm -rf simv.daidir/

run_all:
	@rm -f $(SUMMARY); \
	echo "pattern,result,sim_time,timing_violations,stall_total,stall_load_use,stall_mem,stall_mul,stall_ifetch,stall_dmem,stall_imem,branch_wrong,branch_wrong_cycles,cycle_count" > $(SUMMARY)
	@set -e; \
	overall=pass; \
	for pat in $(PATTERNS); do \
		echo "============================================================"; \
		echo "[RTL] Running $$pat with CHIP=$(CHIP)"; \
		echo "============================================================"; \
		$(MAKE) run PATTERN=$$pat CHIP=$(CHIP); \
		log="vcs_$(CHIP_BASE)_$$pat.log"; \
		if grep -q "CONGRATULATIONS" "$$log"; then result=PASS; \
		elif grep -q "FAIL" "$$log"; then result=FAIL; \
		else result=UNKNOWN; fi; \
		if [ "$$result" != "PASS" ]; then overall=fail; fi; \
		time=$$(awk '/\$$finish at simulation time/ {t=$$NF} END {print t}' "$$log"); \
		viol=$$(grep -c "Timing violation" "$$log" || true); \
		stalls=$$(awk '/STALL_SUMMARY/ {for (i=1;i<=NF;i++) {split($$i,a,"="); v[a[1]]=a[2]}} END {printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s", v["total"]+0, v["load_use"]+0, v["mem"]+0, v["mul"]+0, v["ifetch"]+0, v["dmem"]+0, v["imem"]+0, v["branch_wrong"]+0, v["branch_wrong_cycles"]+0, v["cycles"]+0}' "$$log"); \
		printf "%s,%s,%s,%s,%s\n" "$$pat" "$$result" "$$time" "$$viol" "$$stalls" | tee -a $(SUMMARY); \
	done; \
	final_summary="$(SUMMARY_PREFIX)_$${overall}.csv"; \
	mv $(SUMMARY) "$$final_summary"; \
	echo "============================================================"; \
	echo "[RTL] Summary written to $$final_summary"; \
	cat "$$final_summary"

run3:
	@rm -f $(SUMMARY); \
	echo "pattern,result,sim_time,timing_violations,stall_total,stall_load_use,stall_mem,stall_mul,stall_ifetch,stall_dmem,stall_imem,branch_wrong,branch_wrong_cycles,cycle_count" > $(SUMMARY)
	@set -e; \
	overall=pass; \
	for pat in $(PATTERNS3); do \
		echo "============================================================"; \
		echo "[RTL] Running $$pat with CHIP=$(CHIP)"; \
		echo "============================================================"; \
		$(MAKE) run PATTERN=$$pat CHIP=$(CHIP); \
		log="vcs_$(CHIP_BASE)_$$pat.log"; \
		if grep -q "CONGRATULATIONS" "$$log"; then result=PASS; \
		elif grep -q "FAIL" "$$log"; then result=FAIL; \
		else result=UNKNOWN; fi; \
		if [ "$$result" != "PASS" ]; then overall=fail; fi; \
		time=$$(awk '/\$$finish at simulation time/ {t=$$NF} END {print t}' "$$log"); \
		viol=$$(grep -c "Timing violation" "$$log" || true); \
		stalls=$$(awk '/STALL_SUMMARY/ {for (i=1;i<=NF;i++) {split($$i,a,"="); v[a[1]]=a[2]}} END {printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s", v["total"]+0, v["load_use"]+0, v["mem"]+0, v["mul"]+0, v["ifetch"]+0, v["dmem"]+0, v["imem"]+0, v["branch_wrong"]+0, v["branch_wrong_cycles"]+0, v["cycles"]+0}' "$$log"); \
		printf "%s,%s,%s,%s,%s\n" "$$pat" "$$result" "$$time" "$$viol" "$$stalls" | tee -a $(SUMMARY); \
	done; \
	final_summary="$(SUMMARY_PREFIX)_$${overall}.csv"; \
	mv $(SUMMARY) "$$final_summary"; \
	echo "============================================================"; \
	echo "[RTL] Summary written to $$final_summary"; \
	cat "$$final_summary"
	
help:
	@echo "Usage:"
	@echo "make run PATTERN=LFSR_HIST: run one RTL simulation pattern"
	@echo "make run_all: run all score/check patterns in PATTERNS"
	@echo "make run3: run QSort, Conv, and LFSR_HIST"
	@echo "make run PATTERN=QSort DEFINES=+define+DEBUG_PC: run with extra defines"
	@echo "CHIP=CHIP_xxxxx.v can select the RTL source file"
	@echo "SUMMARY_PREFIX=name can override the summary output prefix"

.PHONY: all run clean run_all run3
