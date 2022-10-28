
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

    localparam ADDR_WIDTH = $clog2(LEN);

    reg [AXI_ID_WIDTH-1:0] id_mem[LEN];
    reg [LEN-1:0]          read_mem;
    reg [LEN-1:0]          valid_mem;
    reg [WIDTH-1:0]        data_mem[LEN];

    wire [ADDR_WIDTH-1:0] match_raddr;
    reg [ADDR_WIDTH:0] raddr;
    wire [ADDR_WIDTH-1:0] mem_raddr;
    reg [ADDR_WIDTH:0] waddr;
    wire [ADDR_WIDTH-1:0] mem_waddr;

    assign mem_raddr = raddr[ADDR_WIDTH-1:0];
    assign mem_waddr = waddr[ADDR_WIDTH-1:0];

    assign full = raddr[ADDR_WIDTH] != waddr[ADDR_WIDTH] && raddr[ADDR_WIDTH-1:0] == waddr[ADDR_WIDTH-1:0];
    assign dout = data_mem[match_raddr];

    wire [$clog2(LEN)+1-1:0][LEN-1:0][ADDR_WIDTH-1:0] distance_matrix;
    wire [$clog2(LEN)+1-1:0][LEN-1:0][ADDR_WIDTH-1:0] match_raddr_matrix;
    wire [$clog2(LEN)+1-1:0][LEN-1:0] valid_matrix;

    for (genvar i = 0; i < LEN; ++i) begin
        assign distance_matrix[0][i] = i - mem_raddr;
        assign valid_matrix[0][i] = dout_id == id_mem[i] && valid_mem[i];
        assign match_raddr_matrix[0][i] = i;
    end

    for (genvar i = 0; i < $clog2(LEN); ++i) begin
        for (genvar j = 0; j < LEN/(2**(i+1)); ++j) begin
            wire left_cond;
            assign left_cond = valid_matrix[i][j*2] && (!valid_matrix[i][j*2+1] || distance_matrix[i][j*2] < distance_matrix[i][j*2+1]);
            assign distance_matrix[i+1][j] = left_cond ? distance_matrix[i][j*2] : distance_matrix[i][j*2+1];
            assign valid_matrix[i+1][j] = left_cond ? valid_matrix[i][j*2] : valid_matrix[i][j*2+1];
            assign match_raddr_matrix[i+1][j] = left_cond ? match_raddr_matrix[i][j*2] : match_raddr_matrix[i][j*2+1];
        end
    end

    assign match_raddr = match_raddr_matrix[$clog2(LEN)][0];

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            raddr <= '0;
            waddr <= '0;
            read_mem <= '0;
            valid_mem <= '0;
        end else begin
            if (write) begin
                valid_mem[mem_waddr] <= 1'b1;
                waddr <= waddr + 1;
            end
            if (read_mem[mem_raddr]) begin
                read_mem[mem_raddr] <= 1'b0;
                raddr <= raddr+1;
            end
            if (read) begin
                valid_mem[match_raddr] <= 1'b0;
                if (dout_id == id_mem[mem_raddr] && valid_mem[mem_raddr]) begin
                    raddr <= raddr+1;
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

