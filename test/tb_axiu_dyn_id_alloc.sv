
module tb_axiu_dyn_id_alloc();

    reg clk;
    reg rstn;
    
    initial begin
        clk = 0;
        rstn = 0;
        #10
        rstn = 1;
    end
    
    always begin
        #1;
        clk = !clk;
    end
    
    localparam MAX_OUTSTANDING_AW = 100;
    localparam MAX_OUTSTANDING_W = 100;
    localparam MAX_OUTSTANDING_R = 100;
    localparam READ_LATENCY = 100;
    localparam READ_BANDWIDTH_UP = 1;
    localparam READ_BANDWIDTH_DOWN = 0;
    localparam READ_BANDWIDTH_RAND = 1;
    localparam READ_BANDWIDTH_UP_PROB = 50;
    localparam READ_BANDWIDTH_DOWN_PROB = 50;
    localparam WRITE_LATENCY = 100;
    localparam WRITE_BANDWIDTH_UP = 1;
    localparam WRITE_BANDWIDTH_DOWN = 0;
    localparam WRITE_BANDWIDTH_RAND = 1;
    localparam WRITE_BANDWIDTH_UP_PROB = 0;
    localparam WRITE_BANDWIDTH_DOWN_PROB = 0;
    localparam TIMER_WIDTH = 64;
    localparam AXI_DATA_WIDTH = 128;
    localparam AXI_ID_SLV_WIDTH = 4;
    localparam AXI_MST_UNIQUE_IDS = 8;
    localparam AXI_ID_MST_WIDTH = $clog2(AXI_MST_UNIQUE_IDS);
    
    AXI_BUS #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_SLV_WIDTH),
        .AXI_USER_WIDTH(1)
    ) axi_driver2dly(),
      axi_dly2idalloc();
    
    AXI_BUS #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_MST_WIDTH),
        .AXI_USER_WIDTH(1)
    ) axi_idalloc2dly(),
      axi_dly2cut(),
      axi_cut2stub();
    
    axiu_driver #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_RANGE_LOW(0),
        .AXI_ID_RANGE_HIGH((2**AXI_ID_SLV_WIDTH)-1),
        .AXI_LEN_RANGE_LOW(0),
        .AXI_LEN_RANGE_HIGH(64/(AXI_DATA_WIDTH/8)-1)
    ) axi_driver_I (
        .clk(clk),
        .rstn(rstn),
        .axi(axi_driver2dly)
    );
    
    axiu_delayer #(
        .MAX_OUTSTANDING_AW(MAX_OUTSTANDING_AW),
        .MAX_OUTSTANDING_W(MAX_OUTSTANDING_W),
        .MAX_OUTSTANDING_R(MAX_OUTSTANDING_R),
        .READ_LATENCY(READ_LATENCY),
        .READ_BANDWIDTH_UP(READ_BANDWIDTH_UP),
        .READ_BANDWIDTH_DOWN(READ_BANDWIDTH_DOWN),
        .READ_BANDWIDTH_RAND(READ_BANDWIDTH_RAND),
        .READ_BANDWIDTH_UP_PROB(READ_BANDWIDTH_UP_PROB),
        .READ_BANDWIDTH_DOWN_PROB(READ_BANDWIDTH_DOWN_PROB),
        .WRITE_LATENCY(WRITE_LATENCY),
        .WRITE_BANDWIDTH_UP(WRITE_BANDWIDTH_UP),
        .WRITE_BANDWIDTH_DOWN(WRITE_BANDWIDTH_DOWN),
        .WRITE_BANDWIDTH_RAND(WRITE_BANDWIDTH_RAND),
        .WRITE_BANDWIDTH_UP_PROB(WRITE_BANDWIDTH_UP_PROB),
        .WRITE_BANDWIDTH_DOWN_PROB(WRITE_BANDWIDTH_DOWN_PROB),
        .TIMER_WIDTH(TIMER_WIDTH)
    ) axiu_delayer_driver2idalloc (
        .clk(clk),
        .arstn(rstn),
        .slv(axi_driver2dly),
        .mst(axi_dly2idalloc)
    );
    
    axiu_dyn_id_alloc #(
        .SLV_AXI_ID_WIDTH(AXI_ID_SLV_WIDTH),
        .MST_UNIQUE_IDS(AXI_MST_UNIQUE_IDS),
        .MAX_TXNS_PER_ID(8)
    ) axiu_dyn_id_alloc_I (
        .clk(clk),
        .arstn(rstn),
        .slv(axi_dly2idalloc),
        .mst(axi_idalloc2dly)
    );
    
    axiu_delayer #(
        .MAX_OUTSTANDING_AW(MAX_OUTSTANDING_AW),
        .MAX_OUTSTANDING_W(MAX_OUTSTANDING_W),
        .MAX_OUTSTANDING_R(MAX_OUTSTANDING_R),
        .READ_LATENCY(READ_LATENCY),
        .READ_BANDWIDTH_UP(READ_BANDWIDTH_UP),
        .READ_BANDWIDTH_DOWN(READ_BANDWIDTH_DOWN),
        .READ_BANDWIDTH_RAND(READ_BANDWIDTH_RAND),
        .READ_BANDWIDTH_UP_PROB(READ_BANDWIDTH_UP_PROB),
        .READ_BANDWIDTH_DOWN_PROB(READ_BANDWIDTH_DOWN_PROB),
        .WRITE_LATENCY(WRITE_LATENCY),
        .WRITE_BANDWIDTH_UP(WRITE_BANDWIDTH_UP),
        .WRITE_BANDWIDTH_DOWN(WRITE_BANDWIDTH_DOWN),
        .WRITE_BANDWIDTH_RAND(WRITE_BANDWIDTH_RAND),
        .WRITE_BANDWIDTH_UP_PROB(WRITE_BANDWIDTH_UP_PROB),
        .WRITE_BANDWIDTH_DOWN_PROB(WRITE_BANDWIDTH_DOWN_PROB),
        .TIMER_WIDTH(TIMER_WIDTH)
    ) axiu_delayer_idalloc2stub (
        .clk(clk),
        .arstn(rstn),
        .slv(axi_idalloc2dly),
        .mst(axi_dly2cut)
    );
    
    axi_cut_intf #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ID_WIDTH(AXI_ID_MST_WIDTH),
        .USER_WIDTH(1)
    ) axi_cut_I (
        .clk_i(clk),
        .rst_ni(rstn),
        .in(axi_dly2cut),
        .out(axi_cut2stub)
    );
    
    axiu_dyn_id_alloc_check #(
        .SLV_AXI_ID_WIDTH(AXI_ID_SLV_WIDTH),
        .MST_UNIQUE_IDS(AXI_MST_UNIQUE_IDS)
    ) axiu_dyn_id_alloc_check_I (
        .clk(clk),
        .rstn(rstn),
        .axi(axi_cut2stub)
    );
    
    axiu_stub #(
        .MAX_OUTSTANDING_AW(64),
        .MAX_OUTSTANDING_W(64),
        .MAX_OUTSTANDING_R(64),
        .AXI_ID_WIDTH(AXI_ID_MST_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(32),
        .RANDOMIZE_RDATA(1),
        .RANDOMIZE_RESP(1)
    ) axiu_stub_I (
        .clk(clk),
        .arstn(rstn),
        .slv(axi_cut2stub)
    );

endmodule
