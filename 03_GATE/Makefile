# Default target
all: 
	make run

# RTL simulation
run:
	vcs -f 03_gate.f -full64 -R +v2k -debug_access+all | tee vcs_sim.log

clean:
	-rm novas*
	-rm ucli.key
	-rm simv
	-rm -rf csrc/
	-rm -rf *.fsdb
	-rm -rf nWaveLog/
	-rm -rf simv.daidir/
	
help:
	@echo "Usage:"
	@echo "make all/run: run gate simulation with pattern defined in 03_gate.f"

.PHONY: all run
