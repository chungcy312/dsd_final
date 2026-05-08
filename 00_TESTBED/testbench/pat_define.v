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
