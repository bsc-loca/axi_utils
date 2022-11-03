
module axiu_id_deserialize_channel #(
    parameter MST_UNIQUE_IDS = 0,
    parameter MAX_TXNS_PER_ID = 0,
    parameter DATA_WIDTH = 0,
    parameter MAX_LEN_PER_TXN = 0,
    parameter MAX_TXNS = 0,
    localparam AXI_ID_WIDTH = $clog2(MST_UNIQUE_IDS)
) (
    input clk,
    input arstn,
    input req_valid,
    output [AXI_ID_WIDTH-1:0] req_id,
    input mst_resp_valid,
    input [DATA_WIDTH-1:0] mst_resp_data,
    input [AXI_ID_WIDTH-1:0] mst_resp_id,
    output slv_resp_valid,
    input slv_resp_ready,
    output [DATA_WIDTH-1:0] slv_resp_data,
    input slv_resp_last
);

    localparam OUTSTANDING_REQ_WIDTH = $clog2(MAX_TXNS_PER_ID+1);

    AxiUtilsFifo #(.WIDTH(DATA_WIDTH)) data_fifo[MST_UNIQUE_IDS]();
    AxiUtilsFifo #(.WIDTH(AXI_ID_WIDTH)) id_fifo();

    wire [DATA_WIDTH-1:0] slv_data[MST_UNIQUE_IDS];
    wire [MST_UNIQUE_IDS-1:0] data_fifo_empty;
    wire [MST_UNIQUE_IDS-1:0] data_fifo_read;
    reg [OUTSTANDING_REQ_WIDTH-1:0] id_outstanding[MST_UNIQUE_IDS];
    logic [AXI_ID_WIDTH-1:0] sel_id;

    axiu_fifo_fallthrough #(
        .WIDTH(AXI_ID_WIDTH),
        .LEN(MAX_TXNS)
    ) id_fifo_I (
        .clk(clk),
        .arstn(arstn),
        .port(id_fifo)
    );

    assign req_id = sel_id;
    assign slv_resp_valid = !id_fifo.empty && !data_fifo_empty[id_fifo.dout];
    assign slv_resp_data = slv_data[id_fifo.dout];

    assign id_fifo.write = req_valid;
    assign id_fifo.din = sel_id;
    assign id_fifo.read = slv_resp_ready && !id_fifo.empty && !data_fifo_empty[id_fifo.dout] && slv_resp_last;

    for (genvar i = 0; i < MST_UNIQUE_IDS; ++i) begin : gen_data_fifos
        axiu_fifo_fallthrough #(
            .WIDTH(DATA_WIDTH),
            .LEN(MAX_TXNS_PER_ID*MAX_LEN_PER_TXN)
        ) data_fifo_I (
            .clk(clk),
            .arstn(arstn),
            .port(data_fifo[i])
        );

        assign data_fifo[i].write = mst_resp_valid && mst_resp_id == i;
        assign data_fifo[i].din = mst_resp_data;
        assign data_fifo[i].read = slv_resp_ready && id_fifo.dout == i && !data_fifo[i].empty;

        assign slv_data[i] = data_fifo[i].dout;
        assign data_fifo_empty[i] = data_fifo[i].empty;
        assign data_fifo_read[i] = data_fifo[i].read;
    end

    always_comb begin
        sel_id = '0;
        if (id_outstanding[0] == MAX_TXNS_PER_ID) begin
            for (int i = 1; i < MST_UNIQUE_IDS; ++i) begin
                if (id_outstanding[i] != MAX_TXNS_PER_ID) begin
                    sel_id = i;
                    break;
                end
            end
        end
    end

    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            for (int i = 0; i < MST_UNIQUE_IDS; ++i) begin
                id_outstanding[i] <= '0;
            end
        end else begin
            if (req_valid && !(data_fifo_read[sel_id] && slv_resp_last)) begin
                id_outstanding[sel_id] <= id_outstanding[sel_id] + 1;
            end
            if ((!req_valid || sel_id != id_fifo.dout) && data_fifo_read[id_fifo.dout] && slv_resp_last) begin
                id_outstanding[id_fifo.dout] <= id_outstanding[id_fifo.dout] - 1;
            end
        end
    end

endmodule
