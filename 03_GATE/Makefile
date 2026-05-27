# Default target
all: 
	make run

PATTERN ?= QSort
PATTERNS ?= noHazard hasHazard BrPred Scaling compression compression_uncompressed QSort_uncompressed QSort Conv Conv_uncompressed Mul LFSR_HIST LFSR_HIST_short
PATTERNS3 ?= QSort Conv LFSR_HIST
VCS_WARN_OPTS ?= +warn=noTFIPC
FOLDER ?= ../02_SYN/Netlist
FOLDER_NOSLASH := $(patsubst %/,%,$(FOLDER))
FOLDER_BASE := $(notdir $(FOLDER_NOSLASH))
RUN_NAME := $(patsubst Netlist_%,%,$(FOLDER_BASE))
ifeq ($(FOLDER_BASE),Netlist)
SYN_CYCLE := default
CHIP_BASE := CHIP
SIM_TIME ?= 3.0
REPORT_FOLDER ?= $(subst Netlist,Report,$(FOLDER_NOSLASH))
else
SYN_CYCLE := $(lastword $(subst _, ,$(RUN_NAME)))
CHIP_BASE := $(patsubst %_$(SYN_CYCLE),%,$(RUN_NAME))
SIM_TIME ?= $(SYN_CYCLE)
REPORT_FOLDER ?= $(subst /Netlist_,/Report_,$(subst Netlist_,Report_,$(FOLDER_NOSLASH)))
endif
AREA_FILE ?= $(REPORT_FOLDER)/$(CHIP_BASE)_syn.area
NETLIST_FILE ?= $(FOLDER_NOSLASH)/$(CHIP_BASE)_syn.v
SDF_FILE ?= $(FOLDER_NOSLASH)/$(CHIP_BASE)_syn.sdf
SUMMARY_PREFIX ?= gate_summary
SUMMARY_TMP ?= $(SUMMARY_PREFIX)_running.csv
SUMMARY ?= $(SUMMARY_TMP)
GATE_FILES = ../00_TESTBED/testbench/Final_tb.v \
             ../00_MEMORY/slow_memory_random_latency.v \
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
		echo "[GATE] Running $$pat with FOLDER=$(FOLDER), SIM_TIME=$(SIM_TIME)"; \
		echo "============================================================"; \
		$(MAKE) clean >/dev/null; \
		$(MAKE) run PATTERN=$$pat FOLDER=$(FOLDER) SIM_TIME=$(SIM_TIME); \
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
	final_summary="$(SUMMARY_PREFIX)_$(CHIP_BASE)_$(SYN_CYCLE)_$(SIM_TIME)_$${overall}.csv"; \
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
		echo "[GATE] Running $$pat with FOLDER=$(FOLDER), SIM_TIME=$(SIM_TIME)"; \
		echo "============================================================"; \
		$(MAKE) clean >/dev/null; \
		$(MAKE) run PATTERN=$$pat FOLDER=$(FOLDER) SIM_TIME=$(SIM_TIME); \
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
	if [ "$$overall" = "pass" ]; then \
		area=$$(awk '/Total cell area:/ {print $$NF; exit}' "$(AREA_FILE)"); \
		score=$$(awk -F, -v area="$$area" 'NR>1 {t[$$1]=$$3} END {printf "%.3e", area * t["QSort"] * t["Conv"] * t["LFSR_HIST"]}' $(SUMMARY) | sed 's/e+//'); \
		final_summary="$(SUMMARY_PREFIX)_$(CHIP_BASE)_$(SYN_CYCLE)_$(SIM_TIME)_$${score}.csv"; \
	else \
		final_summary="$(SUMMARY_PREFIX)_$(CHIP_BASE)_$(SYN_CYCLE)_$(SIM_TIME)_$${overall}.csv"; \
	fi; \
	mv $(SUMMARY) "$$final_summary"; \
	echo "============================================================"; \
	echo "[GATE] Summary written to $$final_summary"; \
	cat "$$final_summary"
	
help:
	@echo "Usage:"
	@echo "make run PATTERN=QSort: run one gate simulation pattern"
	@echo "make run_all: run all score/check patterns in PATTERNS"
	@echo "make run3: run QSort, Conv, and LFSR_HIST"
	@echo "Default FOLDER=../02_SYN/Netlist uses CHIP_syn.v and SIM_TIME=3.0"
	@echo "FOLDER=../02_SYN/Netlist_CHIP_xxxxx_2.9 make run_all"
	@echo "SIM_TIME=3.0 can override the default simulation cycle from FOLDER"
	@echo "SUMMARY_PREFIX=name can override the summary output prefix"

.PHONY: all run clean run_all run3
