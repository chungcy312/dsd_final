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
	-rm -rf build_$(CHIP_BASE)_*/
	-rm -rf csrc/
	-rm -rf *.fsdb
	-rm -rf nWaveLog/
	-rm -rf simv.daidir/

# CSV Header Definition
CSV_HEADER = "pattern,result,sim_time,timing_violations,stall_total,icache_miss,icache_stall,dcache_miss,dcache_stall,stall_lu,stall_mul,br_occ,br_taken,br_pen,jal_occ,jal_taken,jal_pen,jalr_occ,jalr_taken,jalr_pen,cycle_count"

run_all:
	@rm -f $(SUMMARY); \
	echo $(CSV_HEADER) > $(SUMMARY)
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
		stalls=$$(awk -F'|' ' \
			/Total Execution Cycles/ {gsub(/[^0-9]/, "", $$2); cyc=$$2} \
			/Total Global Stalls/ {gsub(/[^0-9]/, "", $$2); tot=$$2} \
			/I-Cache Miss Count/ {gsub(/[^0-9]/, "", $$2); im_m=$$2} \
			/I-Cache Stall Cycles/ {gsub(/[^0-9]/, "", $$2); im_s=$$2} \
			/D-Cache Miss Count/ {gsub(/[^0-9]/, "", $$2); dm_m=$$2} \
			/D-Cache Stall Cycles/ {gsub(/[^0-9]/, "", $$2); dm_s=$$2} \
			/Load-Use Hazard Stall/ {gsub(/[^0-9]/, "", $$2); lu=$$2} \
			/Multiplier Stall/ {gsub(/[^0-9]/, "", $$2); mu=$$2} \
			/\[Branch\] Total Occurrences/ {gsub(/[^0-9]/, "", $$2); bro=$$2} \
			/\[Branch\] Taken Count/ {gsub(/[^0-9]/, "", $$2); brt=$$2} \
			/\[Branch\] Penalty Cycles/ {gsub(/[^0-9]/, "", $$2); brp=$$2} \
			/\[JAL\]    Total Occurrences/ {gsub(/[^0-9]/, "", $$2); jalo=$$2} \
			/\[JAL\]    Taken Count/ {gsub(/[^0-9]/, "", $$2); jalt=$$2} \
			/\[JAL\]    Penalty Cycles/ {gsub(/[^0-9]/, "", $$2); jalp=$$2} \
			/\[JALR\]   Total Occurrences/ {gsub(/[^0-9]/, "", $$2); jalro=$$2} \
			/\[JALR\]   Taken Count/ {gsub(/[^0-9]/, "", $$2); jalrt=$$2} \
			/\[JALR\]   Penalty Cycles/ {gsub(/[^0-9]/, "", $$2); jalrp=$$2} \
			END {printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d", tot+0, im_m+0, im_s+0, dm_m+0, dm_s+0, lu+0, mu+0, bro+0, brt+0, brp+0, jalo+0, jalt+0, jalp+0, jalro+0, jalrt+0, jalrp+0, cyc+0}' "$$log"); \
		printf "%s,%s,%s,%s,%s\n" "$$pat" "$$result" "$$time" "$$viol" "$$stalls" | tee -a $(SUMMARY); \
	done; \
	final_summary="$(SUMMARY_PREFIX)_$${overall}.csv"; \
	mv $(SUMMARY) "$$final_summary"; \
	echo "============================================================"; \
	echo "[RTL] Summary written to $$final_summary"; \
	cat "$$final_summary"

run3:
	@rm -f $(SUMMARY); \
	echo $(CSV_HEADER) > $(SUMMARY)
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
		stalls=$$(awk -F'|' ' \
			/Total Execution Cycles/ {gsub(/[^0-9]/, "", $$2); cyc=$$2} \
			/Total Global Stalls/ {gsub(/[^0-9]/, "", $$2); tot=$$2} \
			/I-Cache Miss Count/ {gsub(/[^0-9]/, "", $$2); im_m=$$2} \
			/I-Cache Stall Cycles/ {gsub(/[^0-9]/, "", $$2); im_s=$$2} \
			/D-Cache Miss Count/ {gsub(/[^0-9]/, "", $$2); dm_m=$$2} \
			/D-Cache Stall Cycles/ {gsub(/[^0-9]/, "", $$2); dm_s=$$2} \
			/Load-Use Hazard Stall/ {gsub(/[^0-9]/, "", $$2); lu=$$2} \
			/Multiplier Stall/ {gsub(/[^0-9]/, "", $$2); mu=$$2} \
			/\[Branch\] Total Occurrences/ {gsub(/[^0-9]/, "", $$2); bro=$$2} \
			/\[Branch\] Taken Count/ {gsub(/[^0-9]/, "", $$2); brt=$$2} \
			/\[Branch\] Penalty Cycles/ {gsub(/[^0-9]/, "", $$2); brp=$$2} \
			/\[JAL\]    Total Occurrences/ {gsub(/[^0-9]/, "", $$2); jalo=$$2} \
			/\[JAL\]    Taken Count/ {gsub(/[^0-9]/, "", $$2); jalt=$$2} \
			/\[JAL\]    Penalty Cycles/ {gsub(/[^0-9]/, "", $$2); jalp=$$2} \
			/\[JALR\]   Total Occurrences/ {gsub(/[^0-9]/, "", $$2); jalro=$$2} \
			/\[JALR\]   Taken Count/ {gsub(/[^0-9]/, "", $$2); jalrt=$$2} \
			/\[JALR\]   Penalty Cycles/ {gsub(/[^0-9]/, "", $$2); jalrp=$$2} \
			END {printf "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d", tot+0, im_m+0, im_s+0, dm_m+0, dm_s+0, lu+0, mu+0, bro+0, brt+0, brp+0, jalo+0, jalt+0, jalp+0, jalro+0, jalrt+0, jalrp+0, cyc+0}' "$$log"); \
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