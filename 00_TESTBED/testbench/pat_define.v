// =========================================================== //
// Information                                          	   //
// =========================================================== //
// [INFO]: Files for different conditions are listed here. 
// [INFO]: Please modify the path if needed (For TAs).
// [INFO]: Students should not modify this file.

// =========================================================== //
// Instruction Definition                                      //
// =========================================================== //
`define INST_NOP 	32'h13_00_00_00;
`define INST_FLUSH	32'h07_20_20_00;

// =========================================================== //
// Baseline Patterns                                           //
// =========================================================== //
`ifdef noHazard
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Hazard_None/I_mem_noHazard"
    `define DMEM_INIT       "../00_TESTBED/pattern/Hazard_None/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Hazard_None/D_gold"
`endif

`ifdef hasHazard
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Hazard/I_mem_hasHazard"
    `define DMEM_INIT       "../00_TESTBED/pattern/Hazard/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Hazard/D_gold"
`endif

`ifdef customHazard
	`define N_MEM_CHECK 	32
	`define IMEM_INIT       "../00_TESTBED/pattern/CustomHazard/I_mem_customHazard"
    `define DMEM_INIT       "../00_TESTBED/pattern/CustomHazard/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/CustomHazard/D_gold"
`endif

`ifdef hazEXMEMForward
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_EXMEMForward/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_EXMEMForward/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_EXMEMForward/D_gold"
`endif

`ifdef hazMEMWBForward
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_MEMWBForward/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_MEMWBForward/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_MEMWBForward/D_gold"
`endif

`ifdef hazStoreDataForward
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_StoreDataForward/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_StoreDataForward/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_StoreDataForward/D_gold"
`endif

`ifdef hazLoadUse
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_LoadUse/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_LoadUse/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_LoadUse/D_gold"
`endif

`ifdef hazLoadBranch
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_LoadBranch/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_LoadBranch/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_LoadBranch/D_gold"
`endif

`ifdef hazBranchForward
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_BranchForward/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_BranchForward/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_BranchForward/D_gold"
`endif

`ifdef hazJALFlush
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_JALFlush/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_JALFlush/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_JALFlush/D_gold"
`endif

`ifdef hazJALRForward
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_JALRForward/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_JALRForward/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_JALRForward/D_gold"
`endif

`ifdef hazJALRNegImm
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_JALRNegImm/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_JALRNegImm/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_JALRNegImm/D_gold"
`endif

`ifdef hazCallReturn
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_CallReturn/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_CallReturn/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_CallReturn/D_gold"
`endif

`ifdef hazDCacheConflictFlush
	`define N_MEM_CHECK 	17
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_DCacheConflictFlush/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_DCacheConflictFlush/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_DCacheConflictFlush/D_gold"
`endif

`ifdef hazFibOnly
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_FibOnly/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_FibOnly/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_FibOnly/D_gold"
`endif

`ifdef hazBubbleOnly
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_BubbleOnly/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_BubbleOnly/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_BubbleOnly/D_gold"
`endif

`ifdef hazFibNoOutput
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_FibNoOutput/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_FibNoOutput/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_FibNoOutput/D_gold"
`endif

`ifdef hazAddiBneLoop
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_AddiBneLoop/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_AddiBneLoop/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_AddiBneLoop/D_gold"
`endif

`ifdef hazAdjacentAddiBne
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_AdjacentAddiBne/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_AdjacentAddiBne/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_AdjacentAddiBne/D_gold"
`endif

`ifdef hazBneBack28
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_BneBack28/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_BneBack28/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_BneBack28/D_gold"
`endif

`ifdef hazFibBodyLoop
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_FibBodyLoop/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_FibBodyLoop/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_FibBodyLoop/D_gold"
`endif

`ifdef hazFibBodyLong
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_FibBodyLong/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_FibBodyLong/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_FibBodyLong/D_gold"
`endif

`ifdef hazFibBodyGap
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_FibBodyGap/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_FibBodyGap/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_FibBodyGap/D_gold"
`endif

`ifdef hazFibInitBodyNoGap
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_FibInitBodyNoGap/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_FibInitBodyNoGap/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_FibInitBodyNoGap/D_gold"
`endif

`ifdef hazBranchFlushJalr
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_BranchFlushJalr/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_BranchFlushJalr/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_BranchFlushJalr/D_gold"
`endif

`ifdef hazStoreBranchFlushJalr
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Haz_StoreBranchFlushJalr/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Haz_StoreBranchFlushJalr/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Haz_StoreBranchFlushJalr/D_gold"
`endif

// =========================================================== //
// Extension Patterns                                          //
// =========================================================== //
`ifdef BrPred
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/BrPred/I_mem_BrPred"
    `define DMEM_INIT       "../00_TESTBED/pattern/BrPred/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/BrPred/D_gold"
`endif 

`ifdef Scaling
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Scaling/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Scaling/D_mem"
    `define GOLDEN          "../00_TESTBED/pattern/Scaling/D_gold"
`endif 

`ifdef compression
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Compression/I_mem_compression"
	`define DMEM_INIT       "../00_TESTBED/pattern/Compression/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Compression/D_gold"
`endif 

`ifdef compression_uncompressed
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Compression/I_mem_decompression"
	`define DMEM_INIT       "../00_TESTBED/pattern/Compression/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Compression/D_gold"
`endif

`ifdef Mul
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Mul/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Mul/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Mul/D_gold"
`endif

`ifdef dbgCJalReturn
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_CJalReturn/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_CJalReturn/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_CJalReturn/D_gold"
`endif

`ifdef dbgCBranch
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_CBranch/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_CBranch/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_CBranch/D_gold"
`endif

`ifdef dbgCrossLoadUse
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_CrossLoadUse/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_CrossLoadUse/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_CrossLoadUse/D_gold"
`endif

`ifdef dbgQSortCallShape
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_QSortCallShape/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_QSortCallShape/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_QSortCallShape/D_gold"
`endif

`ifdef dbgNestedCall
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_NestedCall/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_NestedCall/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_NestedCall/D_gold"
`endif

`ifdef dbgCSlliLoadAddr
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_CSlliLoadAddr/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_CSlliLoadAddr/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_CSlliLoadAddr/D_gold"
`endif

`ifdef dbgCLoadStoreForward
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_CLoadStoreForward/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_CLoadStoreForward/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_CLoadStoreForward/D_gold"
`endif

`ifdef dbgSltCBranchForward
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_SltCBranchForward/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_SltCBranchForward/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_SltCBranchForward/D_gold"
`endif

`ifdef dbgCSwapMini
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_CSwapMini/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_CSwapMini/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_CSwapMini/D_gold"
`endif

`ifdef dbgCBackwardLoop
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_CBackwardLoop/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_CBackwardLoop/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_CBackwardLoop/D_gold"
`endif

`ifdef dbgRedirectUnalign32
	`define N_MEM_CHECK 	16
	`define IMEM_INIT       "../00_TESTBED/pattern/Dbg_RedirectUnalign32/I_mem"
	`define DMEM_INIT       "../00_TESTBED/pattern/Dbg_RedirectUnalign32/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Dbg_RedirectUnalign32/D_gold"
`endif

`ifdef QSort
	`define N_MEM_CHECK 	256
	`define IMEM_INIT 		"../00_TESTBED/pattern/Q_Sort/I_mem_compression"
	`define DMEM_INIT 		"../00_TESTBED/pattern/Q_Sort/D_mem"
	`define GOLDEN 			"../00_TESTBED/pattern/Q_Sort/D_gold"
`endif

`ifdef QSort_uncompressed
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Q_Sort/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Q_Sort/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Q_Sort/D_gold"
`endif

`ifdef Conv
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Conv/I_mem_compression"
    `define DMEM_INIT       "../00_TESTBED/pattern/Conv/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Conv/D_gold"
`endif

`ifdef Conv_uncompressed
	`define N_MEM_CHECK 	256
	`define IMEM_INIT       "../00_TESTBED/pattern/Conv/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/Conv/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/Conv/D_gold"
`endif

`ifdef LFSR_HIST
	`define N_MEM_CHECK 	8200
	`define IMEM_INIT       "../00_TESTBED/pattern/LFSR_HIST/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/LFSR_HIST/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/LFSR_HIST/D_gold"
`endif

`ifdef LFSR_HIST_short
	`define N_MEM_CHECK 	520
	`define IMEM_INIT       "../00_TESTBED/pattern/LFSR_HIST_short/I_mem"
    `define DMEM_INIT       "../00_TESTBED/pattern/LFSR_HIST_short/D_mem"
	`define GOLDEN          "../00_TESTBED/pattern/LFSR_HIST_short/D_gold"
`endif
