
module axiu_reorder_id_fifo #(
    parameter LEN = 0,
    parameter WIDTH = 0,
    parameter AXI_ID_WIDTH = 0
) (
    input clk,
    input arstn,
    output full,
    input write,
    input [AXI_ID_WIDTH-1:0] din_id,
    input [WIDTH-1:0] din,
    input read,
    input [AXI_ID_WIDTH-1:0] dout_id,
    output [WIDTH-1:0] dout
);

    localparam CLOG2LEN = $clog2(LEN);
    localparam LEN_POW2 = 2**CLOG2LEN;
    localparam LAST_IDX = LEN-1;
    localparam CLOG2LEN_0 = {CLOG2LEN{1'b0}};
    localparam CLOG2LEN_1 = {{CLOG2LEN-1{1'b0}}, 1'b1};
    localparam IDX_1 = {{CLOG2LEN{1'b0}}, 1'b1};
    localparam POWER_2 = (LEN & (LEN-1)) == 0;

    reg [AXI_ID_WIDTH-1:0] id_mem[LEN];
    reg [LEN-1:0]          read_mem;
    reg [LEN-1:0]          valid_mem;
    reg [WIDTH-1:0]        data_mem[LEN];

    wire [CLOG2LEN-1:0] match_raddr;
    reg [CLOG2LEN:0] raddr;
    wire [CLOG2LEN:0] next_raddr;
    wire [CLOG2LEN-1:0] mem_raddr;
    reg [CLOG2LEN:0] waddr;
    wire [CLOG2LEN:0] next_waddr;
    wire [CLOG2LEN-1:0] mem_waddr;

    assign mem_raddr = raddr[CLOG2LEN-1:0];
    assign mem_waddr = waddr[CLOG2LEN-1:0];

    assign full = raddr[CLOG2LEN] != waddr[CLOG2LEN] && raddr[CLOG2LEN-1:0] == waddr[CLOG2LEN-1:0];
    assign dout = data_mem[match_raddr];

    wire [$clog2(LEN)+1-1:0][LEN_POW2-1:0][CLOG2LEN-1:0] distance_matrix;
    wire [$clog2(LEN)+1-1:0][LEN_POW2-1:0][CLOG2LEN-1:0] match_raddr_matrix;
    wire [$clog2(LEN)+1-1:0][LEN_POW2-1:0] valid_matrix;

    for (genvar i = 0; i < LEN; ++i) begin : first_dim
        assign distance_matrix[0][i] = i - mem_raddr;
        assign valid_matrix[0][i] = dout_id == id_mem[i] && valid_mem[i];
        assign match_raddr_matrix[0][i] = i;
    end
    for (genvar i = LEN; i < LEN_POW2; ++i) begin
        assign valid_matrix[0][i] = 1'b0;
    end

    for (genvar i = 0; i < $clog2(LEN); ++i) begin : outer_loop
        for (genvar j = 0; j < LEN_POW2/(2**(i+1)); ++j) begin : inner_loop
            wire left_cond;
            assign left_cond = valid_matrix[i][j*2] && (!valid_matrix[i][j*2+1] || distance_matrix[i][j*2] < distance_matrix[i][j*2+1]);
            assign distance_matrix[i+1][j] = left_cond ? distance_matrix[i][j*2] : distance_matrix[i][j*2+1];
            assign valid_matrix[i+1][j] = left_cond ? valid_matrix[i][j*2] : valid_matrix[i][j*2+1];
            assign match_raddr_matrix[i+1][j] = left_cond ? match_raddr_matrix[i][j*2] : match_raddr_matrix[i][j*2+1];
        end
    end

    assign match_raddr = match_raddr_matrix[$clog2(LEN)][0];

    if (POWER_2) begin
        assign next_raddr = next_raddr + IDX_1;
        assign next_waddr = next_waddr + IDX_1;
    end else begin
        assign next_raddr[CLOG2LEN-1:0] = (next_raddr[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? CLOG2LEN_0 : (next_raddr[CLOG2LEN-1:0] + CLOG2LEN_1);
        assign next_raddr[CLOG2LEN] = (next_raddr[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? !next_raddr[CLOG2LEN] : next_raddr[CLOG2LEN];
        assign next_waddr[CLOG2LEN-1:0] = (next_waddr[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? CLOG2LEN_0 : (next_waddr[CLOG2LEN-1:0] + CLOG2LEN_1);
        assign next_waddr[CLOG2LEN] = (next_waddr[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? !next_waddr[CLOG2LEN] : next_waddr[CLOG2LEN];
    end

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            raddr <= '0;
            waddr <= '0;
            read_mem <= '0;
            valid_mem <= '0;
        end else begin
            if (write) begin
                valid_mem[mem_waddr] <= 1'b1;
                waddr <= next_waddr;
            end
            if (read_mem[mem_raddr]) begin
                read_mem[mem_raddr] <= 1'b0;
                raddr <= next_raddr;
            end
            if (read) begin
                valid_mem[match_raddr] <= 1'b0;
                if (dout_id == id_mem[mem_raddr] && valid_mem[mem_raddr]) begin
                    raddr <= next_raddr;
                end else begin
                    read_mem[match_raddr] <= 1'b1;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if (write) begin
            data_mem[mem_waddr] <= din;
            id_mem[mem_waddr] <= din_id;
        end
    end

endmodule

