
module axiu_dyn_id_alloc #(
    parameter SLV_UNIQUE_IDS = 0,
    parameter MST_UNIQUE_IDS = 0,
    parameter MAX_TXNS_PER_ID = 0
) (
    input clk,
    input arstn,
    AXI_BUS.Slave slv,
    AXI_BUS.Master mst
);

    localparam SLV_AXI_ID_WIDTH = $clog2(SLV_UNIQUE_IDS);

    reg ar_stall;
    reg [SLV_AXI_ID_WIDTH-1:0] ar_id_buf;
    wire [SLV_AXI_ID_WIDTH-1:0] r_req_id_mapped;
    wire r_req_ready;
    reg aw_stall;
    wire w_req_ready;
    reg [SLV_AXI_ID_WIDTH-1:0] aw_id_buf;
    wire [SLV_AXI_ID_WIDTH-1:0] w_req_id_mapped;

    assign slv.ar_ready = mst.ar_ready && (ar_stall || r_req_ready);
    assign mst.ar_valid = slv.ar_valid && (ar_stall || r_req_ready);

    assign slv.aw_ready = mst.aw_ready && (aw_stall || w_req_ready);
    assign mst.aw_valid = slv.aw_valid && (aw_stall || w_req_ready);

    assign mst.ar_id = ar_stall ? ar_id_buf : r_req_id_mapped;

    assign mst.ar_addr   = slv.ar_addr;
    assign mst.ar_len    = slv.ar_len;
    assign mst.ar_size   = slv.ar_size;
    assign mst.ar_burst  = slv.ar_burst;
    assign mst.ar_lock   = slv.ar_lock;
    assign mst.ar_cache  = slv.ar_cache;
    assign mst.ar_prot   = slv.ar_prot;
    assign mst.ar_qos    = slv.ar_qos;
    assign mst.ar_region = slv.ar_region;

    assign mst.aw_id = aw_stall ? aw_id_buf : w_req_id_mapped;

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

    assign slv.r_valid = mst.r_valid;
    assign mst.r_ready = slv.r_ready;
    assign slv.r_data = mst.r_data;
    assign slv.r_resp = mst.r_resp;
    assign slv.r_last = mst.r_last;

    assign slv.b_valid = mst.b_valid;
    assign mst.b_ready = slv.b_ready;
    assign slv.b_resp = mst.b_resp;

    axiu_dyn_id_alloc_channel #(
        .SLV_UNIQUE_IDS(SLV_UNIQUE_IDS),
        .MST_UNIQUE_IDS(MST_UNIQUE_IDS),
        .MAX_TXNS_PER_ID(MAX_TXNS_PER_ID)
    ) dyn_id_alloc_R_channel (
        .clk(clk),
        .arstn(arstn),
        .req_valid(slv.ar_valid && !ar_stall),
        .req_ready(r_req_ready),
        .req_id(slv.ar_id),
        .req_id_mapped(r_req_id_mapped),
        .resp_valid(mst.r_valid && slv.r_ready && mst.r_last),
        .resp_id(mst.r_id),
        .resp_id_mapped(slv.r_id)
    );

    axiu_dyn_id_alloc_channel #(
        .SLV_UNIQUE_IDS(SLV_UNIQUE_IDS),
        .MST_UNIQUE_IDS(MST_UNIQUE_IDS),
        .MAX_TXNS_PER_ID(MAX_TXNS_PER_ID)
    ) dyn_id_alloc_W_channel (
        .clk(clk),
        .arstn(arstn),
        .req_valid(slv.aw_valid && !aw_stall),
        .req_ready(w_req_ready),
        .req_id(slv.aw_id),
        .req_id_mapped(w_req_id_mapped),
        .resp_valid(mst.b_valid && slv.b_ready),
        .resp_id(mst.b_id),
        .resp_id_mapped(slv.b_id)
    );

    always_ff @(posedge clk) begin
        if (!ar_stall) begin
            ar_id_buf <= r_req_id_mapped;
        end
        if (!aw_stall) begin
            aw_id_buf <= w_req_id_mapped;
        end
    end

    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            ar_stall <= 1'b0;
            aw_stall <= 1'b0;
        end else begin
            if (slv.ar_valid && r_req_ready && !mst.ar_ready) begin
                ar_stall <= 1'b1;
            end else if (mst.ar_ready) begin
                ar_stall <= 1'b0;
            end
            if (slv.aw_valid && w_req_ready && !mst.aw_ready) begin
                aw_stall <= 1'b1;
            end else if (mst.aw_ready) begin
                aw_stall <= 1'b0;
            end
        end
    end

endmodule
