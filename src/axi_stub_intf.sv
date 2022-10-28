
module axi_stub_intf #(
    parameter MAX_OUTSTANDING_AW = 0,
    parameter MAX_OUTSTANDING_W = 0,
    parameter MAX_OUTSTANDING_R = 0,
    parameter AXI_ID_WIDTH = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_ADDR_WIDTH = 0,
    parameter RANDOMIZE_RDATA = 0,
    parameter RANDOMIZE_RESP = 0
) (
    input clk,
    input arstn,
    AXI_BUS.Slave slv
);

    axi_stub #(
        .MAX_OUTSTANDING_AW(MAX_OUTSTANDING_AW),
        .MAX_OUTSTANDING_W(MAX_OUTSTANDING_W),
        .MAX_OUTSTANDING_R(MAX_OUTSTANDING_R),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .RANDOMIZE_RDATA(RANDOMIZE_RDATA),
        .RANDOMIZE_RESP(RANDOMIZE_RESP)
    ) axi_stub_I (
        .clk(clk),
        .arstn(arstn),
        .s_axi_awid     (slv.aw_id),
        .s_axi_awaddr   (slv.aw_addr),
        .s_axi_awlen    (slv.aw_len),
        .s_axi_awsize   (slv.aw_size),
        .s_axi_awburst  (slv.aw_burst),
        .s_axi_awlock   (slv.aw_lock),
        .s_axi_awcache  (slv.aw_cache),
        .s_axi_awprot   (slv.aw_prot),
        .s_axi_awqos    (slv.aw_qos),
        .s_axi_awregion (slv.aw_region),
        .s_axi_awvalid  (slv.aw_valid),
        .s_axi_awready  (slv.aw_ready),
        .s_axi_wdata    (slv.w_data),
        .s_axi_wstrb    (slv.w_strb),
        .s_axi_wlast    (slv.w_last),
        .s_axi_wvalid   (slv.w_valid),
        .s_axi_wready   (slv.w_ready),
        .s_axi_bid      (slv.b_id),
        .s_axi_bresp    (slv.b_resp),
        .s_axi_bvalid   (slv.b_valid),
        .s_axi_bready   (slv.b_ready),
        .s_axi_arid     (slv.ar_id),
        .s_axi_araddr   (slv.ar_addr),
        .s_axi_arlen    (slv.ar_len),
        .s_axi_arsize   (slv.ar_size),
        .s_axi_arburst  (slv.ar_burst),
        .s_axi_arlock   (slv.ar_lock),
        .s_axi_arcache  (slv.ar_cache),
        .s_axi_arprot   (slv.ar_prot),
        .s_axi_arqos    (slv.ar_qos),
        .s_axi_arregion (slv.ar_region),
        .s_axi_arvalid  (slv.ar_valid),
        .s_axi_arready  (slv.ar_ready),
        .s_axi_rid      (slv.r_id),
        .s_axi_rdata    (slv.r_data),
        .s_axi_rresp    (slv.r_resp),
        .s_axi_rlast    (slv.r_last),
        .s_axi_rvalid   (slv.r_valid),
        .s_axi_rready   (slv.r_ready)
    );

endmodule
