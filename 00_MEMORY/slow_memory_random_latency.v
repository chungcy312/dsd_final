// CAwEDSD spring 2017
// slow_memory interface with handshake signal

// 2025 update
// store the input signals when the state is IDLE
// mem_rdata only valid when mem_ready is high (1 cycle)

// 2026 Pony's update
// Random latency in a given range

module slow_memory_random_latency #(
    parameter MEM_NUM       = 1024,
    parameter MEM_WIDTH     = 128,

    // negedge clock after [Unconditional carry(15ns/CYCLE)+1] cycle
    parameter MIN_LATENCY   = 40,
    parameter MAX_LATENCY   = 50,

    parameter SEED          = 32'h1142D5D
) (
    input                  clk,
    input                  mem_read,
    input                  mem_write,
    input           [27:0] mem_addr,
    input  [MEM_WIDTH-1:0] mem_wdata,
    output [MEM_WIDTH-1:0] mem_rdata,
    output                 mem_ready
);
    integer i;
    integer latency_r;

    integer seed;
    initial seed = SEED;

// ===================================================================== //
// Local parameter                                                       //
// ===================================================================== //
    localparam IDLE          = 2'd0;
    localparam WAIT          = 2'd1; 
    localparam BUBBLE        = 2'd2;

// ===================================================================== //
// Wires / Registers                                                     // 
// ===================================================================== //
    // internal FF
    reg             [31:0] mem[MEM_NUM*4-1:0];
    reg             [31:0] mem_next[MEM_NUM*4-1:0];
    reg     [1:0]          state, state_next;

    // input FF
    reg                    mem_read_r, mem_write_r;
    reg           [27:0]   mem_addr_r;
    reg  [MEM_WIDTH-1:0]   mem_wdata_r;    

    // output FF
    reg                    mem_ready, mem_ready_next;
    reg    [MEM_WIDTH-1:0] mem_rdata, mem_rdata_next;

// ===================================================================== //
// FSM & control signals                                                 //
// ===================================================================== //
    always@(*)begin
        case(state)
            IDLE:
                begin
                    if(mem_read || mem_write) begin
                        state_next = WAIT;
                    end
                    else begin
                        state_next = IDLE;
                    end
                    
                    mem_ready_next = 1'b0;
                end
            WAIT:
                begin
                    latency_r = MIN_LATENCY + (($random(seed) & 32'h7fffffff) % (MAX_LATENCY - MIN_LATENCY + 1));
                    // $display("current latency: %d", latency_r);
                    #(latency_r);
                    state_next = BUBBLE;
                    mem_ready_next = 1'b0;
                end
            BUBBLE:
                begin
                    // mem_ready PULL UP just 1 cycle
                    state_next = IDLE;
                    mem_ready_next = 1'b1;
                end
            default:
                begin
                    state_next = IDLE;
                    mem_ready_next = 1'b0;
                end     
        endcase
    end
    
    always@(*) begin // Mem array
        mem_rdata_next = 0;

        for(i=0;i<MEM_NUM*4;i=i+1)
            mem_next[i] = mem[i];
    
        if( state ==  BUBBLE) begin
            if( ~mem_read_r && mem_write_r ) begin
                mem_next[mem_addr_r*4]      = mem_wdata_r[31:0];
                mem_next[mem_addr_r*4+1]    = mem_wdata_r[63:32];
                mem_next[mem_addr_r*4+2]    = mem_wdata_r[95:64];
                mem_next[mem_addr_r*4+3]    = mem_wdata_r[127:96];
            end
            
            if( mem_read_r && ~mem_write_r ) begin
                mem_rdata_next = {mem[mem_addr_r*4+3],mem[mem_addr_r*4+2],mem[mem_addr_r*4+1],mem[mem_addr_r*4]};
            end
        end
    end

    always@( negedge clk ) begin
        state <= state_next;
        
        mem_ready <= mem_ready_next;
        mem_rdata  <= mem_rdata_next;
        
        for(i=0;i<MEM_NUM*4;i=i+1)
            mem[i] <= mem_next[i];
    end

    always@( negedge clk ) begin
        mem_read_r  <=  (state == IDLE)? mem_read : mem_read_r;
        mem_write_r <=  (state == IDLE)? mem_write : mem_write_r;
        mem_addr_r  <=  (state == IDLE)? mem_addr : mem_addr_r;
        mem_wdata_r <=  (state == IDLE)? mem_wdata : mem_wdata_r;
    end

    initial begin
        mem_read_r  =  1'b0;
        mem_write_r =  1'b0;
        mem_addr_r  =  28'd0;
        mem_wdata_r =  {MEM_WIDTH{1'b0}};
        state       =  IDLE;
        mem_ready   =  1'b0;
    end

endmodule
  
  