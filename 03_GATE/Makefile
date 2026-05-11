# Default target
all: 
	make run

PATTERN ?= QSort
PATTERNS ?= noHazard hasHazard BrPred Scaling compression compression_uncompressed QSort_uncompressed QSort Conv Conv_uncompressed Mul LFSR_HIST LFSR_HIST_short
PATTERNS3 ?= QSort Conv LFSR_HIST
VCS_WARN_OPTS ?= +warn=noTFIPC
SUMMARY ?= gate_summary.csv

# RTL simulation
run:
	vcs -f 03_gate.f +define+$(PATTERN) $(VCS_WARN_OPTS) -full64 -R +v2k -debug_access+all | tee vcs_$(PATTERN).log

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
	echo "pattern,result,sim_time,timing_violations" > $(SUMMARY)
	@set -e; \
	for pat in $(PATTERNS); do \
		echo "============================================================"; \
		echo "[GATE] Running $$pat"; \
		echo "============================================================"; \
		$(MAKE) clean >/dev/null; \
		$(MAKE) run PATTERN=$$pat; \
		if grep -q "CONGRATULATIONS" vcs_$$pat.log; then result=PASS; \
		elif grep -q "FAIL" vcs_$$pat.log; then result=FAIL; \
		else result=UNKNOWN; fi; \
		time=$$(awk '/\$$finish at simulation time/ {t=$$NF} END {print t}' vcs_$$pat.log); \
		viol=$$(grep -c "Timing violation" vcs_$$pat.log || true); \
		printf "%s,%s,%s,%s\n" "$$pat" "$$result" "$$time" "$$viol" | tee -a $(SUMMARY); \
	done
	@echo "============================================================"; \
	echo "[GATE] Summary written to $(SUMMARY)"; \
	cat $(SUMMARY)

run3:
	@rm -f $(SUMMARY); \
	echo "pattern,result,sim_time,timing_violations" > $(SUMMARY)
	@set -e; \
	for pat in $(PATTERNS3); do \
		echo "============================================================"; \
		echo "[GATE] Running $$pat"; \
		echo "============================================================"; \
		$(MAKE) clean >/dev/null; \
		$(MAKE) run PATTERN=$$pat; \
		if grep -q "CONGRATULATIONS" vcs_$$pat.log; then result=PASS; \
		elif grep -q "FAIL" vcs_$$pat.log; then result=FAIL; \
		else result=UNKNOWN; fi; \
		time=$$(awk '/\$$finish at simulation time/ {t=$$NF} END {print t}' vcs_$$pat.log); \
		viol=$$(grep -c "Timing violation" vcs_$$pat.log || true); \
		printf "%s,%s,%s,%s\n" "$$pat" "$$result" "$$time" "$$viol" | tee -a $(SUMMARY); \
	done
	@echo "============================================================"; \
	echo "[GATE] Summary written to $(SUMMARY)"; \
	cat $(SUMMARY)
	
help:
	@echo "Usage:"
	@echo "make run PATTERN=QSort: run one gate simulation pattern"
	@echo "make run_all: run all score/check patterns in PATTERNS"
	@echo "make run3: run QSort, Conv, and LFSR_HIST"
	@echo "SUMMARY=filename.csv can override the summary output path"

.PHONY: all run clean run_all run3
