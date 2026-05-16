module icache_2way #(
    parameter BLOCKS = 32
) (
    input          clk,
    input          rst_n,
    input          req,
    input  [31:0]  addr,
    output [31:0]  rdata,
    output         ready,

    output         mem_read,
    output         mem_write,
    output [31:4]  mem_addr,
    output [127:0] mem_wdata,
    input  [127:0] mem_rdata,
    input          mem_ready
);
function integer clog2;
    input integer value;
    integer v;
    begin
        v = value - 1;
        for (clog2 = 0; v > 0; clog2 = clog2 + 1) begin
            v = v >> 1;
        end
    end
endfunction

function [31:0] select_word;
    input [127:0] line;
    input [1:0]   index;
    begin
        case (index)
            2'd0: select_word = line[31:0];
            2'd1: select_word = line[63:32];
            2'd2: select_word = line[95:64];
            2'd3: select_word = line[127:96];
        endcase
    end
endfunction

localparam SETS     = (BLOCKS >> 1);
localparam SET_BITS = clog2(SETS);
localparam TAG_BITS = 28 - SET_BITS;
localparam S_IDLE   = 1'b0;
localparam S_REFILL = 1'b1;

reg state;
reg [31:0] addr_r;
reg victim_way_r;
reg [31:4] mem_addr_r;
reg replace_way [0:SETS-1];
reg [127:0] data0 [0:SETS-1];
reg [127:0] data1 [0:SETS-1];
reg [TAG_BITS-1:0] tag0 [0:SETS-1];
reg [TAG_BITS-1:0] tag1 [0:SETS-1];
reg valid0 [0:SETS-1];
reg valid1 [0:SETS-1];

wire [SET_BITS-1:0] set_idx = addr[4 + SET_BITS - 1:4];
wire [SET_BITS-1:0] set_idx_r = addr_r[4 + SET_BITS - 1:4];
wire [TAG_BITS-1:0] tag_addr = addr[31:4 + SET_BITS];
wire [TAG_BITS-1:0] tag_addr_r = addr_r[31:4 + SET_BITS];
wire [1:0] word_idx = addr[3:2];
wire [1:0] word_idx_r = addr_r[3:2];
wire hit0 = valid0[set_idx] && (tag0[set_idx] == tag_addr);
wire hit1 = valid1[set_idx] && (tag1[set_idx] == tag_addr);
wire hit = hit0 | hit1;
wire [31:0] word0 = select_word(data0[set_idx], word_idx);
wire [31:0] word1 = select_word(data1[set_idx], word_idx);
wire [31:0] refill_word = select_word(mem_rdata, word_idx_r);
integer si;

assign rdata = (state == S_REFILL) ? refill_word :
               hit1 ? word1 : word0;
assign ready = (state == S_IDLE && req && hit) ||
               (state == S_REFILL && mem_ready);
assign mem_read = (state == S_REFILL);
assign mem_write = 1'b0;
assign mem_addr = mem_addr_r;
assign mem_wdata = 128'b0;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= S_IDLE;
        victim_way_r <= 1'b0;
        for (si = 0; si < SETS; si = si + 1) begin
            replace_way[si] <= 1'b0;
            valid0[si] <= 1'b0;
            valid1[si] <= 1'b0;
        end
    end else begin
        case (state)
            S_IDLE: begin
                if (req && !hit) begin
                    addr_r <= addr;
                    victim_way_r <= replace_way[set_idx];
                    mem_addr_r <= addr[31:4];
                    state <= S_REFILL;
                end
            end
            S_REFILL: begin
                if (mem_ready) begin
                    if (victim_way_r) begin
                        data1[set_idx_r] <= mem_rdata;
                        tag1[set_idx_r] <= tag_addr_r;
                        valid1[set_idx_r] <= 1'b1;
                    end else begin
                        data0[set_idx_r] <= mem_rdata;
                        tag0[set_idx_r] <= tag_addr_r;
                        valid0[set_idx_r] <= 1'b1;
                    end
                    replace_way[set_idx_r] <= ~victim_way_r;
                    state <= S_IDLE;
                end
            end
        endcase
    end
end

endmodule
