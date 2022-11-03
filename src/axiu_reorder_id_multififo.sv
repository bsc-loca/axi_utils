
module axiu_reorder_id_multififo #(
    parameter LEN = 0,
    parameter WIDTH = 0,
    parameter UNIQUE_IDS = 0,
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

    AxiUtilsFifo #(.WIDTH(WIDTH)) fifo_port[UNIQUE_IDS]();

    wire [WIDTH-1:0] fifo_dout[UNIQUE_IDS];
    wire [UNIQUE_IDS-1:0] fifo_full;

    assign full = fifo_full[din_id];
    assign dout = fifo_dout[dout_id];

    for (genvar i = 0; i < UNIQUE_IDS; ++i) begin : gen_fifos
        axiu_fifo_fallthrough #(
            .WIDTH(WIDTH),
            .LEN(LEN)
        ) fifo_I (
            .clk(clk),
            .arstn(arstn),
            .port(fifo_port[i])
        );

        assign fifo_port[i].write = write && din_id == i;
        assign fifo_port[i].din = din;
        assign fifo_port[i].read = read && dout_id == i;
        assign fifo_dout[i] = fifo_port[i].dout;
        assign fifo_full[i] = fifo_port[i].full;
    end

endmodule
