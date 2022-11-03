
module tb_axiu_id_deserialize();

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

    localparam AXI_DATA_WIDTH = 128;
    localparam AXI_MST_UNIQUE_IDS = 8;
    localparam AXI_ID_MST_WIDTH = $clog2(AXI_MST_UNIQUE_IDS);
    localparam MAX_TXNS_PER_ID = 8;
    localparam MAX_LEN_PER_TXN = 4;
    localparam MAX_TXNS = 60;
    localparam MAX_OUTSTANDING_AW = MAX_TXNS-1;
    localparam MAX_OUTSTANDING_W = MAX_TXNS-1;
    localparam MAX_OUTSTANDING_R = MAX_TXNS-1;
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

    AXI_BUS #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(1),
        .AXI_USER_WIDTH(1)
    ) axi_driver2dly(),
      axi_dly2dut();

    AXI_BUS #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_MST_WIDTH),
        .AXI_USER_WIDTH(1)
    ) axi_dut2dly(),
      axi_dly2cut(),
      axi_cut2stub();

    axiu_driver #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ID_RANGE_LOW(0),
        .AXI_ID_RANGE_HIGH(0),
        .AXI_LEN_RANGE_LOW(0),
        .AXI_LEN_RANGE_HIGH(64/(AXI_DATA_WIDTH/8)-1),
        .AXI_SIZE_RANGE_LOW($clog2(AXI_DATA_WIDTH/8)),
        .AXI_SIZE_RANGE_HIGH($clog2(AXI_DATA_WIDTH/8))
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
    ) axiu_delayer_driver2dut (
        .clk(clk),
        .arstn(rstn),
        .slv(axi_driver2dly),
        .mst(axi_dly2dut)
    );

    axiu_id_deserialize #(
        .MST_UNIQUE_IDS(AXI_MST_UNIQUE_IDS),
        .MAX_TXNS_PER_ID(MAX_TXNS_PER_ID),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .MAX_LEN_PER_TXN(MAX_LEN_PER_TXN),
        .MAX_TXNS(MAX_TXNS)
    ) axiu_id_deserialize_I (
        .clk(clk),
        .arstn(rstn),
        .slv(axi_dly2dut),
        .mst(axi_dut2dly)
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
    ) axiu_delayer_dut2stub (
        .clk(clk),
        .arstn(rstn),
        .slv(axi_dut2dly),
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

    axiu_id_deserialize_check #(
        .MST_UNIQUE_IDS(AXI_MST_UNIQUE_IDS)
    ) axiu_id_deserialize_check_I (
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
