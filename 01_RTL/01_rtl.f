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
# DUT                                                  #
########################################################
CHIP.v


########################################################
# Standard cell library                                #
########################################################
// -y /usr/cad/synopsys/synthesis/cur/dw/sim_ver +libext+.v
// +incdir+/usr/cad/synopsys/synthesis/cur/dw/sim_ver/+

########################################################
# Dump FSDB                                            #
########################################################
// +define+FSDB

########################################################
# Defines for debug                                    #
########################################################


########################################################
# Pattern Definition                                   #
########################################################
// +define+noHazard
+define+hasHazard
// +define+customHazard
// +define+hazEXMEMForward
// +define+hazMEMWBForward
// +define+hazStoreDataForward
// +define+hazLoadUse
// +define+hazLoadBranch
// +define+hazBranchForward
// +define+hazJALFlush
// +define+hazJALRForward
// +define+hazJALRNegImm
// +define+hazCallReturn
// +define+hazDCacheConflictFlush
// +define+hazFibOnly
// +define+hazBubbleOnly
// +define+hazFibNoOutput
// +define+hazAddiBneLoop
// +define+hazAdjacentAddiBne
// +define+hazBneBack28
// +define+hazFibBodyLoop
// +define+hazFibBodyLong
// +define+hazFibBodyGap
// +define+hazFibInitBodyNoGap
// +define+hazBranchFlushJalr
// +define+hazStoreBranchFlushJalr

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
