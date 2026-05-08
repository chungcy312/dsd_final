// =========================================================== //
// Testbench Definition                                        //
// =========================================================== //
`define CYCLE       10                  // You can modify your clock frequency
`define MAX_CYCLES  10000000            // You can modify the max cycle count to stop the simulaiton
`define SDFFILE     "./CHIP_syn.sdf"

// fast_memory or slow_memory or slow_memory_random_latency
`define MEMORY_CELL slow_memory_random_latency         
// `define PRINT_SUCCESS_INFO 1