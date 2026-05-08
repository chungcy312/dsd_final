########################################################
# TESTBED                                              #
########################################################
../00_TESTBED/testbench/Final_tb.v

########################################################
# Memory                                               #
########################################################
../00_MEMORY/slow_memory_random_latency.v
../00_MEMORY/slow_memory.v
../00_MEMORY/fast_memory.v

########################################################
# Flush Instruction Definition                         #
########################################################
../00_TESTBED/testbench/flush_inst_define.v

########################################################
# Synthesized Design                                   #
########################################################
../02_SYN/Netlist/CHIP_syn.v

########################################################
# Standard cell library                                #
########################################################
-v /home/raid7_2/course/cvsd/CBDK_IC_Contest/CIC/Verilog/tsmc13.v


########################################################
# Dump FSDB                                            #
########################################################
// +define+FSDB

########################################################
# Defines for debug                                    #
########################################################

########################################################
# Gate simulation flag                                 #
########################################################
+define+SDF
+define+SDFFILE=\"../02_SYN/Netlist/CHIP_syn.sdf\"

########################################################
# Cycle Time (Period)                                  #
########################################################
+define+CYCLE=1000.0

########################################################
# Pattern Definition                                   #
########################################################
+define+noHazard
// +define+hasHazard

// +define+BrPred
// +define+Scaling
// +define+compression
// +define+compression_uncompressed

// +define+QSort_uncompressed
// +define+QSort
// +define+Conv
// +define+Conv_uncompressed
// +define+Mul

// +define+LFSR_HIST
// +define+LFSR_HIST_short