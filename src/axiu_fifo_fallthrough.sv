
module axiu_fifo_fallthrough #(
    parameter WIDTH = 0,
    parameter LEN = 0
) (
    input clk,
    input arstn,
    AxiUtilsFifo.slave port
);

    localparam CLOG2LEN = $clog2(LEN);
    localparam LAST_IDX = LEN-1;
    localparam CLOG2LEN_0 = {CLOG2LEN{1'b0}};
    localparam CLOG2LEN_1 = {{CLOG2LEN-1{1'b0}}, 1'b1};
    localparam IDX_0 = {CLOG2LEN+1{1'b0}};
    localparam IDX_1 = {{CLOG2LEN{1'b0}}, 1'b1};
    localparam POWER_2 = (LEN & (LEN-1)) == 0;

    reg [CLOG2LEN:0] read_idx;
    wire [CLOG2LEN:0] next_read_idx;
    reg [CLOG2LEN:0] write_idx;
    wire [CLOG2LEN:0] next_write_idx;

    assign port.empty = read_idx == write_idx;
    assign port.full = read_idx[CLOG2LEN-1:0] == write_idx[CLOG2LEN-1:0] && read_idx[CLOG2LEN] != write_idx[CLOG2LEN];

    if (POWER_2) begin
        assign next_read_idx = read_idx + IDX_1;
        assign next_write_idx = write_idx + IDX_1;
    end else begin
        assign next_read_idx[CLOG2LEN-1:0] = (read_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? CLOG2LEN_0 : (read_idx[CLOG2LEN-1:0] + CLOG2LEN_1);
        assign next_read_idx[CLOG2LEN] = (read_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? !read_idx[CLOG2LEN] : read_idx[CLOG2LEN];
        assign next_write_idx[CLOG2LEN-1:0] = (write_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? CLOG2LEN_0 : (write_idx[CLOG2LEN-1:0] + CLOG2LEN_1);
        assign next_write_idx[CLOG2LEN] = (write_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) ? !write_idx[CLOG2LEN] : write_idx[CLOG2LEN];
    end

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            read_idx <= IDX_0;
            write_idx <= IDX_0;
        end else begin
            if (port.read) begin
                read_idx <= next_read_idx;
            end
            if (port.write) begin
                write_idx <= next_write_idx;
            end
        end
    end

    reg [WIDTH-1:0] mem[LEN];

    always_ff @(posedge clk) begin
        port.dout <= mem[read_idx[CLOG2LEN-1:0]];
        if (port.write && port.empty || (port.write && port.read && next_read_idx[CLOG2LEN-1:0] == write_idx[CLOG2LEN-1:0])) begin
            port.dout <= port.din;
        end else if (port.read) begin
            port.dout <= mem[next_read_idx[CLOG2LEN-1:0]];
        end
        if (port.write) begin
            mem[write_idx[CLOG2LEN-1:0]] <= port.din;
        end
    end

endmodule

