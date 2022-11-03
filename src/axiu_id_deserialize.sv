
module axiu_id_deserialize #(
    parameter MST_UNIQUE_IDS = 0,
    parameter MAX_TXNS_PER_ID = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter MAX_LEN_PER_TXN = 0,
    parameter MAX_TXNS = 0
) (
    input clk,
    input arstn,
    AXI_BUS.Slave slv,
    AXI_BUS.Master mst
);

    localparam AXI_ID_WIDTH = $clog2(MST_UNIQUE_IDS);
    localparam OUTSTANDING_REQ_WIDTH = $clog2(MAX_TXNS_PER_ID+1);

    typedef struct packed {
        logic [AXI_DATA_WIDTH-1:0] data;
        logic [2:0] resp;
        logic last;
    } RDataBeat_t;

    RDataBeat_t mst_rdata;
    RDataBeat_t slv_rdata;

    assign mst_rdata.data = mst.r_data;
    assign mst_rdata.resp = mst.r_resp;
    assign mst_rdata.last = mst.r_last;

    assign slv.ar_ready = mst.ar_ready;
    assign mst.ar_valid = slv.ar_valid;

    assign slv.aw_ready = mst.aw_ready;
    assign mst.aw_valid = slv.aw_valid;

    assign mst.ar_addr   = slv.ar_addr;
    assign mst.ar_len    = slv.ar_len;
    assign mst.ar_size   = slv.ar_size;
    assign mst.ar_burst  = slv.ar_burst;
    assign mst.ar_lock   = slv.ar_lock;
    assign mst.ar_cache  = slv.ar_cache;
    assign mst.ar_prot   = slv.ar_prot;
    assign mst.ar_qos    = slv.ar_qos;
    assign mst.ar_region = slv.ar_region;

    assign mst.aw_addr   = slv.aw_addr;
    assign mst.aw_len    = slv.aw_len;
    assign mst.aw_size   = slv.aw_size;
    assign mst.aw_burst  = slv.aw_burst;
    assign mst.aw_lock   = slv.aw_lock;
    assign mst.aw_cache  = slv.aw_cache;
    assign mst.aw_prot   = slv.aw_prot;
    assign mst.aw_qos    = slv.aw_qos;
    assign mst.aw_region = slv.aw_region;

    assign mst.w_valid = slv.w_valid;
    assign slv.w_ready = mst.w_ready;
    assign mst.w_data = slv.w_data;
    assign mst.w_strb = slv.w_strb;
    assign mst.w_last = slv.w_last;

    assign mst.r_ready = 1'b1;
    assign slv.r_data = slv_rdata.data;
    assign slv.r_resp = slv_rdata.resp;
    assign slv.r_last = slv_rdata.last;
    assign slv.r_id = '0;

    assign mst.b_ready = 1'b1;
    assign slv.b_id = '0;

    axiu_id_deserialize_channel #(
        .MST_UNIQUE_IDS(MST_UNIQUE_IDS),
        .MAX_TXNS_PER_ID(MAX_TXNS_PER_ID),
        .DATA_WIDTH($bits(RDataBeat_t)),
        .MAX_LEN_PER_TXN(MAX_LEN_PER_TXN),
        .MAX_TXNS(MAX_TXNS)
    ) axiu_deserialize_R_channel (
        .clk(clk),
        .arstn(arstn),
        .req_valid(slv.ar_valid && mst.ar_ready),
        .req_id(mst.ar_id),
        .mst_resp_valid(mst.r_valid),
        .mst_resp_data(mst_rdata),
        .mst_resp_id(mst.r_id),
        .slv_resp_valid(slv.r_valid),
        .slv_resp_ready(slv.r_ready),
        .slv_resp_data(slv_rdata),
        .slv_resp_last(slv_rdata.last)
    );

    axiu_id_deserialize_channel #(
        .MST_UNIQUE_IDS(MST_UNIQUE_IDS),
        .MAX_TXNS_PER_ID(MAX_TXNS_PER_ID),
        .DATA_WIDTH(2),
        .MAX_LEN_PER_TXN(MAX_LEN_PER_TXN),
        .MAX_TXNS(MAX_TXNS)
    ) axiu_deserialize_W_channel (
        .clk(clk),
        .arstn(arstn),
        .req_valid(slv.aw_valid && mst.aw_ready),
        .req_id(mst.aw_id),
        .mst_resp_valid(mst.b_valid),
        .mst_resp_data(mst.b_resp),
        .mst_resp_id(mst.b_id),
        .slv_resp_valid(slv.b_valid),
        .slv_resp_ready(slv.b_ready),
        .slv_resp_data(slv.b_resp),
        .slv_resp_last(1'b1)
    );

endmodule
