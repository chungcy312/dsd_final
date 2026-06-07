/*
    Author:         Pony Wang (Revised for Accurate Stall/Penalty Profiling)
    Last Edition:   2026/03/24 (Updated with Cache Miss & Branch Details)
    Description:    
        Testbench for Final Project (RISC-V Pipelined Processor)
        After recieved done signal from processor, the testbench will check the correctness of the result (data in slow_memD)
    Note: 
        The design is connected at testbench, include:
            1. CHIP (RISCV + D_cache + I_chache)
            2. slow memory for data
            3. slow memory for instruction
*/

`timescale 1 ns/10 ps

`include "../00_TESTBED/testbench/tb_define.v"
`include "../00_TESTBED/testbench/pat_define.v"

module Final_tb;
    // ======================================= //
    // Design I/O                              //
    // ======================================= //
    reg             clk;
    reg             rst_n;
    wire            mem_read_D;
    wire            mem_write_D;
    wire [31:4]     mem_addr_D;
    wire [127:0]    mem_wdata_D;
    wire [127:0]    mem_rdata_D;
    wire            mem_ready_D;
    wire            mem_read_I;
    wire            mem_write_I;
    wire [31:4]     mem_addr_I;
    wire [127:0]    mem_wdata_I;
    wire [127:0]    mem_rdata_I;
    wire            mem_ready_I;
    wire            done;

    // ======================================= //
    // Utils                                   //
    // ======================================= //
    integer i;
    reg  [10:0]     error_cnt;
    reg             flag_flush_padded;
    reg  [31:0]     golden_ans [0:`N_MEM_CHECK];

    // ======================================= //
    // DEBUG & PROFILING COUNTERS              //
    // ======================================= //
    integer cycle_count;
    integer report_cycle_count = 1000;
    
    // Stall 原有統計
    integer stall_total_count;
    integer stall_load_use_count;
    integer stall_mem_count;
    integer stall_mul_count;
    integer stall_ifetch_count;
    integer stall_dmem_count;
    integer stall_imem_count;
    integer branch_wrong_count;
    integer branch_wrong_cycle_count;

    // 新增：Cache Miss 邊緣偵測與統計 (SDF/RTL 皆可用)
    integer icache_miss_count;
    integer dcache_miss_count;
    reg mem_read_I_d1;
    reg mem_read_D_d1;
    reg mem_write_D_d1;

    // 新增：Branch / JAL / JALR 細項統計 (限 RTL 精準分析)
    integer inst_branch_count;
    integer inst_jal_count;
    integer inst_jalr_count;
    integer branch_taken_count;
    integer jal_taken_count;
    integer jalr_taken_count;
    integer branch_penalty_cycles;
    integer jal_penalty_cycles;
    integer jalr_penalty_cycles;

`ifdef SDF
    reg        sdf_branch_seen;
    reg [31:0] sdf_branch_pc_seen;
    wire       sdf_branch_in_ex;
    wire [31:0] sdf_branch_pc;

    assign sdf_branch_in_ex = chip0.core0_idex_valid && chip0.core0_idex_branch;
    assign sdf_branch_pc = {chip0.core0_idex_pc, 1'b0};
`endif

    initial cycle_count = 0;

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
        end else if (!done) begin
            cycle_count <= cycle_count + 1;
            if ((cycle_count != 0) && (cycle_count % report_cycle_count == 0)) begin
                $display("Current cycle = %0d", cycle_count);
            end
        end
    end

    // ======================================= //
    // STALL & PENALTY CALCULATION LOGIC       //
    // ======================================= //
    always @(posedge clk) begin
        if (!rst_n) begin
            stall_total_count <= 0;
            stall_load_use_count <= 0;
            stall_mem_count <= 0;
            stall_mul_count <= 0;
            stall_ifetch_count <= 0;
            stall_dmem_count <= 0;
            stall_imem_count <= 0;
            branch_wrong_count <= 0;
            branch_wrong_cycle_count <= 0;
            
            // 新增歸零
            icache_miss_count <= 0;
            dcache_miss_count <= 0;
            mem_read_I_d1 <= 0;
            mem_read_D_d1 <= 0;
            mem_write_D_d1 <= 0;
            inst_branch_count <= 0;
            inst_jal_count <= 0;
            inst_jalr_count <= 0;
            branch_taken_count <= 0;
            jal_taken_count <= 0;
            jalr_taken_count <= 0;
            branch_penalty_cycles <= 0;
            jal_penalty_cycles <= 0;
            jalr_penalty_cycles <= 0;

`ifdef SDF
            sdf_branch_seen <= 1'b0;
            sdf_branch_pc_seen <= 32'b0;
`endif
        end else if (!done) begin
            
            // ----------------------------------------------------
            // 1. Cache Miss 邊緣偵測 (放在最外層，RTL/SDF 皆可精準抓取)
            // ----------------------------------------------------
            mem_read_I_d1 <= mem_read_I;
            mem_read_D_d1 <= mem_read_D;
            mem_write_D_d1 <= mem_write_D;

            // 只要 mem_read_I 從 0 變 1，代表發出了一次 Miss 請求
            if (mem_read_I && !mem_read_I_d1) begin
                icache_miss_count <= icache_miss_count + 1;
            end
            if ((mem_read_D && !mem_read_D_d1) || (mem_write_D && !mem_write_D_d1)) begin
                dcache_miss_count <= dcache_miss_count + 1;
            end

`ifdef SDF
            // ----------------------------------------------------
            // SDF Simulation Logic (維持原本的統計方式)
            // ----------------------------------------------------
            if (sdf_branch_in_ex) begin
                if (!sdf_branch_seen || (sdf_branch_pc_seen != sdf_branch_pc)) begin
                    branch_wrong_count <= branch_wrong_count + 1;
                    branch_wrong_cycle_count <= branch_wrong_cycle_count + 2;
                end
                sdf_branch_seen <= 1'b1;
                sdf_branch_pc_seen <= sdf_branch_pc;
            end else begin
                sdf_branch_seen <= 1'b0;
            end
            if ((mem_read_D || mem_write_D) && !mem_ready_D) begin
                stall_dmem_count <= stall_dmem_count + 1;
            end
            if ((mem_read_I || mem_write_I) && !mem_ready_I) begin
                stall_imem_count <= stall_imem_count + 1;
                stall_ifetch_count <= stall_ifetch_count + 1;
            end
            if (((mem_read_D || mem_write_D) && !mem_ready_D) ||
                ((mem_read_I || mem_write_I) && !mem_ready_I)) begin
                stall_mem_count <= stall_mem_count + 1;
            end
            if (chip0.core0_ex_stage0_mul_busy) begin
                stall_mul_count <= stall_mul_count + 1;
            end
            if (((mem_read_D || mem_write_D) && !mem_ready_D) ||
                ((mem_read_I || mem_write_I) && !mem_ready_I) ||
                chip0.core0_ex_stage0_mul_busy) begin
                stall_total_count <= stall_total_count + 1;
            end
`else
            // ----------------------------------------------------
            // RTL Simulation Logic (安全逐行計算版 + 細項追蹤)
            // ----------------------------------------------------
            
            // 1. Total Stall 安全疊加法
            if (chip0.core0.if_stall) begin
                stall_total_count <= stall_total_count + 1;
            end else if (!chip0.core0.done_r && !chip0.core0.if_ready) begin
                stall_total_count <= stall_total_count + 1; // 補算 I-Cache Miss
            end else if (chip0.core0.ex_redirect_valid || chip0.core0.id_jal_redirect) begin
                stall_total_count <= stall_total_count + 1; // 補算 Branch 氣泡
            end

            // 2. 原本各別細項計算
            if (chip0.core0.load_use_stall) begin
                stall_load_use_count <= stall_load_use_count + 1;
            end
            if (chip0.core0.mem_busy) begin
                stall_mem_count <= stall_mem_count + 1;
            end
            if ((mem_read_D || mem_write_D) && !mem_ready_D) begin
                stall_dmem_count <= stall_dmem_count + 1;
            end
            if ((mem_read_I || mem_write_I) && !mem_ready_I) begin
                stall_imem_count <= stall_imem_count + 1;
            end
            if (chip0.core0.mul_stall) begin
                stall_mul_count <= stall_mul_count + 1;
            end
            if (!chip0.core0.done_r && !chip0.core0.if_ready) begin
                stall_ifetch_count <= stall_ifetch_count + 1;
            end
            
            // 3. 指令發生次數統計 (成功進入 ID Stage 且沒被 Stall)
            // if (chip0.core0.ifid_valid && !chip0.core0.load_use_stall && !chip0.core0.mul_stall) begin
            if (chip0.core0.ifid_valid && !chip0.core0.load_use_stall && !chip0.core0.mul_stall && !chip0.core0.global_stall) begin
                if (chip0.core0.id_branch) inst_branch_count <= inst_branch_count + 1;
                if (chip0.core0.id_jal)    inst_jal_count <= inst_jal_count + 1;
                if (chip0.core0.id_jalr)   inst_jalr_count <= inst_jalr_count + 1;
            end

            // 4. 細分的跳轉與 Penalty 統計
            // 加上 !global_stall 與 !mul_stall，防止 EX Stage 凍結時重複計數
            if (chip0.core0.ex_redirect_valid && !chip0.core0.global_stall && !chip0.core0.mul_stall) begin
                // EX stage 解析的跳轉 (Branch Taken 或 JALR)
                if (chip0.core0.idex_branch) begin
                    branch_taken_count <= branch_taken_count + 1;
                    branch_penalty_cycles <= branch_penalty_cycles + 2;
                    branch_wrong_count <= branch_wrong_count + 1;
                    branch_wrong_cycle_count <= branch_wrong_cycle_count + 2;
                end else if (chip0.core0.idex_jalr) begin
                    jalr_taken_count <= jalr_taken_count + 1;
                    jalr_penalty_cycles <= jalr_penalty_cycles + 2;
                    branch_wrong_count <= branch_wrong_count + 1;
                    branch_wrong_cycle_count <= branch_wrong_cycle_count + 2;
                end
            end
            if (chip0.core0.id_jal_redirect) begin
                // ID stage 解析的跳轉 (JAL，Penalty只有1)
                jal_taken_count <= jal_taken_count + 1;
                jal_penalty_cycles <= jal_penalty_cycles + 1;
                branch_wrong_count <= branch_wrong_count + 1;
                branch_wrong_cycle_count <= branch_wrong_cycle_count + 1;
            end
`endif
        end
    end

    // ======================================= //
    // Module Instantiation                    //
    // ======================================= //
    generate        
        CHIP chip0 (
            .clk            (clk),
            .rst_n          (rst_n),
            // ~ For slow_memD  
            .mem_read_D     (mem_read_D),
            .mem_write_D    (mem_write_D),
            .mem_addr_D     (mem_addr_D),
            .mem_wdata_D    (mem_wdata_D),
            .mem_rdata_D    (mem_rdata_D),
            .mem_ready_D    (mem_ready_D),
            // ~ For slow_memI
            .mem_read_I     (mem_read_I),
            .mem_write_I    (mem_write_I),
            .mem_addr_I     (mem_addr_I),
            .mem_wdata_I    (mem_wdata_I),
            .mem_rdata_I    (mem_rdata_I),
            .mem_ready_I    (mem_ready_I),
            // ~ For Testbench
            .o_done         (done)
        );

        `MEMORY_CELL #(.MEM_NUM(`N_MEM_CHECK)) slow_memD(
            .clk        (clk)           ,
            .mem_read   (mem_read_D)    ,
            .mem_write  (mem_write_D)   ,
            .mem_addr   (mem_addr_D)    ,
            .mem_wdata  (mem_wdata_D)   ,
            .mem_rdata  (mem_rdata_D)   ,
            .mem_ready  (mem_ready_D)
        );

        `MEMORY_CELL slow_memI(
            .clk        (clk)           ,
            .mem_read   (mem_read_I)    ,
            .mem_write  (mem_write_I)   ,
            .mem_addr   (mem_addr_I)    ,
            .mem_wdata  (mem_wdata_I)   ,
            .mem_rdata  (mem_rdata_I)   ,
            .mem_ready  (mem_ready_I)
        );
    endgenerate

    initial begin   // * Display current pattern information
        `ifdef noHazard
            $display("[INFO]: Testing with pattern <noHazard>");
        `elsif hasHazard
            $display("[INFO]: Testing with pattern <hasHazard>");
        `elsif customHazard
            $display("[INFO]: Testing with pattern <customHazard>");
        `elsif hazEXMEMForward
            $display("[INFO]: Testing with pattern <hazEXMEMForward>");
        `elsif hazMEMWBForward
            $display("[INFO]: Testing with pattern <hazMEMWBForward>");
        `elsif hazStoreDataForward
            $display("[INFO]: Testing with pattern <hazStoreDataForward>");
        `elsif hazLoadUse
            $display("[INFO]: Testing with pattern <hazLoadUse>");
        `elsif hazLoadBranch
            $display("[INFO]: Testing with pattern <hazLoadBranch>");
        `elsif hazBranchForward
            $display("[INFO]: Testing with pattern <hazBranchForward>");
        `elsif hazJALFlush
            $display("[INFO]: Testing with pattern <hazJALFlush>");
        `elsif hazJALRForward
            $display("[INFO]: Testing with pattern <hazJALRForward>");
        `elsif hazJALRNegImm
            $display("[INFO]: Testing with pattern <hazJALRNegImm>");
        `elsif hazCallReturn
            $display("[INFO]: Testing with pattern <hazCallReturn>");
        `elsif hazDCacheConflictFlush
            $display("[INFO]: Testing with pattern <hazDCacheConflictFlush>");
        `elsif hazFibOnly
            $display("[INFO]: Testing with pattern <hazFibOnly>");
        `elsif hazBubbleOnly
            $display("[INFO]: Testing with pattern <hazBubbleOnly>");
        `elsif hazFibNoOutput
            $display("[INFO]: Testing with pattern <hazFibNoOutput>");
        `elsif hazAddiBneLoop
            $display("[INFO]: Testing with pattern <hazAddiBneLoop>");
        `elsif hazAdjacentAddiBne
            $display("[INFO]: Testing with pattern <hazAdjacentAddiBne>");
        `elsif hazBneBack28
            $display("[INFO]: Testing with pattern <hazBneBack28>");
        `elsif hazFibBodyLoop
            $display("[INFO]: Testing with pattern <hazFibBodyLoop>");
        `elsif hazFibBodyLong
            $display("[INFO]: Testing with pattern <hazFibBodyLong>");
        `elsif hazFibBodyGap
            $display("[INFO]: Testing with pattern <hazFibBodyGap>");
        `elsif hazFibInitBodyNoGap
            $display("[INFO]: Testing with pattern <hazFibInitBodyNoGap>");
        `elsif hazBranchFlushJalr
            $display("[INFO]: Testing with pattern <hazBranchFlushJalr>");
        `elsif hazStoreBranchFlushJalr
            $display("[INFO]: Testing with pattern <hazStoreBranchFlushJalr>");
        `elsif BrPred
            $display("[INFO]: Testing with pattern <BrPred>");
        `elsif Scaling
            $display("[INFO]: Testing with pattern <Scaling>");
        `elsif compression
            $display("[INFO]: Testing with pattern <compression>");
        `elsif compression_uncompressed
            $display("[INFO]: Testing with pattern <compression_uncompressed>");
        `elsif QSort
            $display("[INFO]: Testing with pattern <QSort>");
        `elsif QSort_uncompressed
            $display("[INFO]: Testing with pattern <QSort_uncompressed>");
        `elsif Conv
            $display("[INFO]: Testing with pattern <Conv>");
        `elsif Conv_uncompressed
            $display("[INFO]: Testing with pattern <Conv_uncompressed>");
        `elsif Mul
            $display("[INFO]: Testing with pattern <Mul>");
        `elsif dbgCJalReturn
            $display("[INFO]: Testing with pattern <dbgCJalReturn>");
        `elsif dbgCBranch
            $display("[INFO]: Testing with pattern <dbgCBranch>");
        `elsif dbgCrossLoadUse
            $display("[INFO]: Testing with pattern <dbgCrossLoadUse>");
        `elsif dbgQSortCallShape
            $display("[INFO]: Testing with pattern <dbgQSortCallShape>");
        `elsif dbgNestedCall
            $display("[INFO]: Testing with pattern <dbgNestedCall>");
        `elsif dbgCSlliLoadAddr
            $display("[INFO]: Testing with pattern <dbgCSlliLoadAddr>");
        `elsif dbgCLoadStoreForward
            $display("[INFO]: Testing with pattern <dbgCLoadStoreForward>");
        `elsif dbgSltCBranchForward
            $display("[INFO]: Testing with pattern <dbgSltCBranchForward>");
        `elsif dbgCSwapMini
            $display("[INFO]: Testing with pattern <dbgCSwapMini>");
        `elsif dbgCBackwardLoop
            $display("[INFO]: Testing with pattern <dbgCBackwardLoop>");
        `elsif dbgRedirectUnalign32
            $display("[INFO]: Testing with pattern <dbgRedirectUnalign32>");
        `elsif LFSR_HIST
            $display("[INFO]: Testing with pattern <LFSR_HIST>");
        `elsif LFSR_HIST_short
            $display("[INFO]: Testing with pattern <LFSR_HIST_short>");
        `else
            $display("[ERROR]: Testing with pattern <unknown>");
            $finish;
        `endif 
    end
    
    initial begin   // ~ Initialize the data memory from files
        $readmemh (`GOLDEN,    golden_ans );
        $readmemh (`DMEM_INIT, slow_memD.mem ); // initialize data in DMEM
        $readmemh (`IMEM_INIT, slow_memI.mem ); // initialize data in IMEM

        // ^ Pad instruction set with [FLUSH+N*NOP]
        flag_flush_padded = 1'b0;
        for (i=0; i<slow_memI.MEM_NUM*4; i=i+1) begin
            if (slow_memI.mem[i] === 32'hxx_xx_xx_xx) begin
                if (~flag_flush_padded) begin
                    slow_memI.mem[i] = `INST_FLUSH; // padding the IMEM with flush instruction
                    flag_flush_padded = 1'b1;
                end
                else begin
                    slow_memI.mem[i] = `INST_NOP;   // padding the IMEM with NOP instruction
                end
            end
        end
    end

    initial begin   // SDF Annotation
        `ifdef SDF
            $sdf_annotate(`SDFFILE, chip0);
        `endif
    end

    initial begin   // FSDB Dump
        `ifdef FSDB
            // waveform dump
            $fsdbDumpfile("Final.fsdb");
            $fsdbDumpvars(0,Final_tb,"+mda");
            $fsdbDumpvars;
        `endif
    end

    initial begin   // ^ Simulation Start
        DISPLAY_START_INFO;

        error_cnt = 0;
        clk = 1;
        rst_n = 1'b1;
        RESET_DESIGN();
    end

    initial begin   // ! Time Limitation Exceeded
        // calculate clock cycles for all operation (you can modify it)
        #(`CYCLE * `MAX_CYCLES) 
        DISPLAY_TLE_INFO;
        $finish;
    end

    // Clock Generation
    always #(`CYCLE*0.5) clk = ~clk;
    
    // Check Result
    always @(done) begin
        if (done) begin
            #(`CYCLE*10)    CHECK_SLOW_MEMORY_D_RESULT;
            #(`CYCLE)       REPORT_RESULT;
            #(`CYCLE)       $finish;
        end
    end

task RESET_DESIGN;
    begin
        $display("==================================");
        $display("Reset ...");
        $display("==================================");
        #(`CYCLE*1.6) rst_n = 1'b0;
        #(`CYCLE*5.0) rst_n = 1'b1;
        $display("[%0t] Reset done", $time);
    end
endtask

task CHECK_SLOW_MEMORY_D_RESULT;
    begin
        for (i=0; i<`N_MEM_CHECK; i=i+1) begin
            if (golden_ans[i] !== slow_memD.mem[i]) begin
                @(negedge clk);
                $display("[ERROR  ]: golden_ans[%3d] = %h, slow_memD.mem[%3d] = %h", i, golden_ans[i], i, slow_memD.mem[i]);
                error_cnt = error_cnt + 1;
            end
            else begin
                `ifdef PRINT_SUCCESS_INFO
                    @(negedge clk);
                    $display("[SUCCESS]: golden_ans[%3d] = %h, slow_memD.mem[%3d] = %h", i, golden_ans[i], i, slow_memD.mem[i]);
                `endif 
            end
        end
    end
endtask

task DISPLAY_START_INFO;
    begin
        $display("-----------------------------------------------------\n");
        $display("START!!! Simulation Start .....\n");
        $display("-----------------------------------------------------\n");
    end
endtask

task DISPLAY_TLE_INFO;
    begin
        $display("============================================================================");
        $display("\n           Error!!! There is something wrong with your code ...!          ");
        $display("\n                       The test result is .....FAIL                     \n");
        $display("============================================================================");
    end
endtask

task DISPLAY_SUCCESS_INFO;
    begin
        $display("============================================================================");
        $display("\n \\(^o^)/ CONGRATULATIONS!!  The simulation result is PASS!!!\n");
        $display("============================================================================");
    end
endtask

task DISPLAY_FAILED_INFO;
    begin
        $display("============================================================================");
        $display("\n (T_T) FAIL!! The simulation result is FAIL!!! there were %d errors at all.\n", error_cnt);
        $display("============================================================================");
    end
endtask

task REPORT_RESULT;
    begin
        DISPLAY_STALL_SUMMARY;
        if (error_cnt == 0) begin
            $system("../00_TESTBED/info/success");
            DISPLAY_SUCCESS_INFO;
        end
        else begin
            $system("../00_TESTBED/info/failed");
            DISPLAY_FAILED_INFO;
        end
    end
endtask

task DISPLAY_STALL_SUMMARY;
    begin
        $display("");
        $display("======================================================================");
        $display("                        PERFORMANCE SUMMARY                           ");
        $display("======================================================================");
        $display(" Metric                             | Count / Cycles");
        $display("------------------------------------|---------------------------------");
        $display(" Total Execution Cycles             | %10d", cycle_count);
        $display(" Total Global Stalls                | %10d", stall_total_count);
        $display("------------------------------------|---------------------------------");
        $display(" [Memory] I-Cache Miss Count        | %10d Times", icache_miss_count);
        $display(" [Memory] I-Cache Stall Cycles      | %10d Cycles", stall_imem_count);
        $display(" [Memory] D-Cache Miss Count        | %10d Times", dcache_miss_count);
        $display(" [Memory] D-Cache Stall Cycles      | %10d Cycles", stall_dmem_count);
        $display("------------------------------------|---------------------------------");
        $display(" [Data]   Load-Use Hazard Stall     | %10d Cycles", stall_load_use_count);
        $display(" [ALU]    Multiplier Stall          | %10d Cycles", stall_mul_count);
        $display("------------------------------------|---------------------------------");
        $display(" [Branch] Total Occurrences         | %10d Times", inst_branch_count);
        $display(" [Branch] Taken Count               | %10d Times", branch_taken_count);
        $display(" [Branch] Penalty Cycles            | %10d Cycles", branch_penalty_cycles);
        $display("------------------------------------|---------------------------------");
        $display(" [JAL]    Total Occurrences         | %10d Times", inst_jal_count);
        $display(" [JAL]    Taken Count               | %10d Times", jal_taken_count);
        $display(" [JAL]    Penalty Cycles            | %10d Cycles", jal_penalty_cycles);
        $display("------------------------------------|---------------------------------");
        $display(" [JALR]   Total Occurrences         | %10d Times", inst_jalr_count);
        $display(" [JALR]   Taken Count               | %10d Times", jalr_taken_count);
        $display(" [JALR]   Penalty Cycles            | %10d Cycles", jalr_penalty_cycles);
        $display("======================================================================");
        $display("");
    end
endtask

task print_file;
    input [1023:0] filename;
    integer fd;
    integer c;
    begin
    fd = $fopen(filename, "r");
    if (fd == 0) begin
        $display("ERROR: cannot open file: %0s", filename);
    end else begin
        while (!$feof(fd)) begin
        c = $fgetc(fd);
        if (c != -1)
            $write("%c", c);
        end
        $fclose(fd);
    end
    end
endtask

endmodule