
module axiu_dwidth_upsizer #(
    parameter AXI_ID_WIDTH = 0,
    parameter MAX_OUTSTANDING_REQ = 0,
    parameter AXI_SLV_DATA_WIDTH = 0,
    parameter AXI_MST_DATA_WIDTH = 0,
    parameter MAX_TXNS_PER_ID = 0,
    parameter UNIQUE_IDS = 0,
    parameter QUEUE_PER_ID = 1
) (
    input clk,
    input arstn,
    AXI_BUS.Slave slv,
    AXI_BUS.Master mst
);

    localparam AXI_MST_WSTRB_WIDTH = AXI_MST_DATA_WIDTH/8;
    localparam AXI_SLV_WSTRB_WIDTH = AXI_SLV_DATA_WIDTH/8;
    localparam SLV_TRANSFER_SIZE = AXI_SLV_DATA_WIDTH/8;
    localparam MST_TRANSFER_SIZE = AXI_MST_DATA_WIDTH/8;
    localparam TXN_SIZE = SLV_TRANSFER_SIZE*256;
    localparam TXN_SIZE_BITS = $clog2(TXN_SIZE+1);
    localparam SLV_ALIGN_BITS = $clog2(SLV_TRANSFER_SIZE);
    localparam MST_ALIGN_BITS = $clog2(MST_TRANSFER_SIZE);

    wire [TXN_SIZE_BITS-1:0]  aw_transaction_size;
    wire [MST_ALIGN_BITS-1:0] aw_addr_align_mask;
    wire [MST_ALIGN_BITS-1:0] aw_addr_aligned;
    wire [TXN_SIZE_BITS-1:0]  aw_len_bytes;
    wire [TXN_SIZE_BITS-1:0]  ar_transaction_size;
    wire [MST_ALIGN_BITS-1:0] ar_addr_align_mask;
    wire [MST_ALIGN_BITS-1:0] ar_addr_aligned;
    wire [TXN_SIZE_BITS-1:0]  ar_len_bytes;

    typedef struct packed {
        reg [MST_ALIGN_BITS-1:0] initial_alignment;
        reg [SLV_ALIGN_BITS:0] burst_size;
    } WAlignInfo_t;

    typedef struct packed {
        reg [MST_ALIGN_BITS-1:0] initial_alignment;
        reg [2:0] ar_size;
        reg [7:0] ar_len;
    } RAlignInfo_t;

    typedef enum bit [0:0] {
        IDLE,
        TRANSACTION
    } AlignState_t;

    AlignState_t w_buf_state;
    AlignState_t r_buf_state;

    RAlignInfo_t ar_align_fifo_din;
    RAlignInfo_t ar_align_fifo_dout;
    wire ar_align_fifo_full;
    wire ar_align_fifo_write;
    wire ar_align_fifo_read;

    WAlignInfo_t aw_align_fifo_din;
    WAlignInfo_t aw_align_fifo_dout;
    AxiUtilsFifo #(.WIDTH($bits(WAlignInfo_t))) aw_align_fifo_port();

    assign ar_addr_align_mask[MST_ALIGN_BITS-1:SLV_ALIGN_BITS] = {MST_ALIGN_BITS-SLV_ALIGN_BITS{1'b1}};
    assign ar_addr_align_mask[SLV_ALIGN_BITS-1:0] = {SLV_ALIGN_BITS{1'b1}} << slv.ar_size;
    assign ar_addr_aligned = slv.ar_addr[MST_ALIGN_BITS-1:0] & ar_addr_align_mask;
    assign ar_len_bytes = (slv.ar_len + {{TXN_SIZE_BITS-1{1'b0}}, 1'b1}) << slv.ar_size;
    assign ar_transaction_size = ar_addr_aligned + ar_len_bytes;
    assign mst.ar_len = (ar_transaction_size >> MST_ALIGN_BITS[2:0]) + (|ar_transaction_size[MST_ALIGN_BITS-1:0]) - 1'b1;

    assign mst.ar_valid  = slv.ar_valid && !ar_align_fifo_full;
    assign slv.ar_ready  = mst.ar_ready && !ar_align_fifo_full;
    assign mst.ar_id     = slv.ar_id;
    assign mst.ar_addr   = slv.ar_addr;
    assign mst.ar_size   = MST_ALIGN_BITS[2:0];
    assign mst.ar_burst  = slv.ar_burst;
    assign mst.ar_lock   = slv.ar_lock;
    assign mst.ar_cache  = slv.ar_cache;
    assign mst.ar_prot   = slv.ar_prot;
    assign mst.ar_qos    = slv.ar_qos;
    assign mst.ar_region = slv.ar_region;

    assign aw_addr_align_mask[MST_ALIGN_BITS-1:SLV_ALIGN_BITS] = {MST_ALIGN_BITS-SLV_ALIGN_BITS{1'b1}};
    assign aw_addr_align_mask[SLV_ALIGN_BITS-1:0] = {SLV_ALIGN_BITS{1'b1}} << slv.aw_size;
    assign aw_addr_aligned = slv.aw_addr[MST_ALIGN_BITS-1:0] & aw_addr_align_mask;
    assign aw_len_bytes = (slv.aw_len + {{TXN_SIZE_BITS-1{1'b0}}, 1'b1}) << slv.aw_size;
    assign aw_transaction_size = aw_addr_aligned + aw_len_bytes;
    assign mst.aw_len = (aw_transaction_size >> MST_ALIGN_BITS[2:0]) + (|aw_transaction_size[MST_ALIGN_BITS-1:0]) - 1'b1;

    assign mst.aw_atop   = '0;
    assign mst.aw_valid  = slv.aw_valid && !aw_align_fifo_port.full;
    assign slv.aw_ready  = mst.aw_ready && !aw_align_fifo_port.full;
    assign mst.aw_id     = slv.aw_id;
    assign mst.aw_addr   = slv.aw_addr;
    assign mst.aw_size   = MST_ALIGN_BITS[2:0];
    assign mst.aw_burst  = slv.aw_burst;
    assign mst.aw_lock   = slv.aw_lock;
    assign mst.aw_cache  = slv.aw_cache;
    assign mst.aw_prot   = slv.aw_prot;
    assign mst.aw_qos    = slv.aw_qos;
    assign mst.aw_region = slv.aw_region;

    assign slv.b_valid = mst.b_valid;
    assign mst.b_ready = slv.b_ready;
    assign slv.b_resp  = mst.b_resp;
    assign slv.b_id    = mst.b_id;

    logic write_w_data_buf;
    reg [AXI_MST_DATA_WIDTH-1:0]  w_data_buf;
    reg [AXI_MST_WSTRB_WIDTH-1:0] w_strb_buf;
    reg w_last_buf;
    reg w_buf_full;
    reg [MST_ALIGN_BITS-1:0] w_align_state;
    wire [MST_ALIGN_BITS:0] next_w_align_state;
    wire [SLV_ALIGN_BITS:0] w_burst_size;
    wire w_align_overflow;

    reg [MST_ALIGN_BITS-1:0] r_align_state;
    wire [MST_ALIGN_BITS:0] next_r_align_state;
    reg [SLV_ALIGN_BITS:0] r_burst_size;
    reg [7:0] r_len;
    wire r_align_overflow;

    wire [AXI_SLV_DATA_WIDTH-1:0] bit_slv_w_strb;

    for (genvar i = 0; i < AXI_SLV_DATA_WIDTH; i += 8) begin
        assign bit_slv_w_strb[i +: 8] = {8{slv.w_strb[i/8]}};
    end

    assign mst.w_valid = w_buf_state == TRANSACTION && w_buf_full;
    assign slv.w_ready = w_buf_state == TRANSACTION && (!w_buf_full || (mst.w_ready && !w_last_buf));
    assign mst.w_data = w_data_buf;
    assign mst.w_strb = w_strb_buf;
    assign mst.w_last = w_last_buf;

    assign slv.r_valid = r_buf_state == TRANSACTION && mst.r_valid;
    assign mst.r_ready = slv.r_ready && r_buf_state == TRANSACTION && (r_align_overflow || r_len == 8'd0);
    assign slv.r_last = r_len == 8'd0;
    assign slv.r_resp = mst.r_resp;
    assign slv.r_id = mst.r_id;

    assign ar_align_fifo_read = r_buf_state == TRANSACTION && mst.r_valid && slv.r_ready && r_len == 8'd0;
    assign ar_align_fifo_write = slv.ar_valid && mst.ar_ready && !ar_align_fifo_full;
    assign ar_align_fifo_din.initial_alignment = slv.ar_addr[MST_ALIGN_BITS-1:0];
    assign ar_align_fifo_din.ar_size = slv.ar_size;
    assign ar_align_fifo_din.ar_len = slv.ar_len;

    assign aw_align_fifo_port.write = slv.aw_valid && mst.aw_ready && !aw_align_fifo_port.full;
    assign aw_align_fifo_port.read = w_buf_state == TRANSACTION && w_buf_full && mst.w_ready && w_last_buf;
    assign aw_align_fifo_din.initial_alignment = slv.aw_addr[MST_ALIGN_BITS-1:0];
    assign aw_align_fifo_din.burst_size = {{SLV_ALIGN_BITS{1'b0}}, 1'b1} << slv.aw_size;
    assign aw_align_fifo_port.din = aw_align_fifo_din;
    assign aw_align_fifo_dout = aw_align_fifo_port.dout;

    assign w_burst_size = aw_align_fifo_dout.burst_size;
    assign next_w_align_state = w_align_state + w_burst_size;
    assign w_align_overflow = next_w_align_state[MST_ALIGN_BITS];

    assign next_r_align_state = r_align_state + r_burst_size;
    assign r_align_overflow = next_r_align_state[MST_ALIGN_BITS];

    if (QUEUE_PER_ID) begin : multi_fifo
        axiu_reorder_id_multififo #(
            .LEN(MAX_TXNS_PER_ID),
            .AXI_ID_WIDTH(AXI_ID_WIDTH),
            .WIDTH($bits(RAlignInfo_t)),
            .UNIQUE_IDS(UNIQUE_IDS)
        ) reorder_axi_id_multififo_I (
            .clk(clk),
            .arstn(arstn),
            .full(ar_align_fifo_full),
            .write(ar_align_fifo_write),
            .din_id(slv.ar_id),
            .din(ar_align_fifo_din),
            .read(ar_align_fifo_read),
            .dout_id(mst.r_id),
            .dout(ar_align_fifo_dout)
        );
    end else begin : single_fifo
        axiu_reorder_id_fifo #(
            .LEN(MAX_OUTSTANDING_REQ),
            .AXI_ID_WIDTH(AXI_ID_WIDTH),
            .WIDTH($bits(RAlignInfo_t))
        ) reorder_axi_id_fifo_I (
            .clk(clk),
            .arstn(arstn),
            .full(ar_align_fifo_full),
            .write(ar_align_fifo_write),
            .din_id(slv.ar_id),
            .din(ar_align_fifo_din),
            .read(ar_align_fifo_read),
            .dout_id(mst.r_id),
            .dout(ar_align_fifo_dout)
        );
    end

    axiu_fifo_fallthrough #(
        .WIDTH($bits(WAlignInfo_t)),
        .LEN(MAX_OUTSTANDING_REQ)
    ) aw_align_info (
        .clk(clk),
        .arstn(arstn),
        .port(aw_align_fifo_port)
    );

    always_comb begin
        write_w_data_buf = 1'b0;
        if (w_buf_state == TRANSACTION) begin
            if (!w_buf_full) begin
                write_w_data_buf = slv.w_valid;
            end else begin
                write_w_data_buf = slv.w_valid && mst.w_ready;
            end
        end
    end

    for (genvar i = 0; i < AXI_MST_DATA_WIDTH/AXI_SLV_DATA_WIDTH; ++i) begin
        localparam DATA_L = i*AXI_SLV_DATA_WIDTH;
        localparam DATA_H = DATA_L + AXI_SLV_DATA_WIDTH - 1;
        localparam WSTRB_L = i*AXI_SLV_WSTRB_WIDTH;
        localparam WSTRB_H = WSTRB_L + AXI_SLV_WSTRB_WIDTH - 1;

        always_ff @(posedge clk, negedge arstn) begin
            if (!arstn) begin
                w_data_buf[DATA_H:DATA_L] <= {AXI_SLV_DATA_WIDTH{1'b0}};
                w_strb_buf[WSTRB_H:WSTRB_L] <= {AXI_SLV_WSTRB_WIDTH{1'b0}};
            end else begin
                if (write_w_data_buf) begin
                    if (w_align_state[MST_ALIGN_BITS-1:SLV_ALIGN_BITS] == i[MST_ALIGN_BITS-SLV_ALIGN_BITS-1:0]) begin
                        w_data_buf[DATA_H:DATA_L] <= (w_data_buf[DATA_H:DATA_L] & ~bit_slv_w_strb) | (slv.w_data & bit_slv_w_strb);
                        if (w_buf_full) begin
                            w_strb_buf[WSTRB_H:WSTRB_L] <= slv.w_strb;
                        end else begin
                            w_strb_buf[WSTRB_H:WSTRB_L] <= w_strb_buf[WSTRB_H:WSTRB_L] | slv.w_strb;
                        end
                    end else if (w_buf_full) begin
                        w_strb_buf[WSTRB_H:WSTRB_L] <= {AXI_SLV_WSTRB_WIDTH{1'b0}};
                    end
                end else if (w_buf_state == IDLE || (w_buf_full && mst.w_ready && !slv.w_valid)) begin
                    w_strb_buf[WSTRB_H:WSTRB_L] <= {AXI_SLV_WSTRB_WIDTH{1'b0}};
                end
            end
        end
    end

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            w_buf_state <= IDLE;
        end else begin

            if (write_w_data_buf) begin
                w_last_buf <= slv.w_last;
            end

            case (w_buf_state)

                IDLE: begin
                    w_buf_full <= 1'b0;
                    w_align_state <= aw_align_fifo_dout.initial_alignment;
                    if (!aw_align_fifo_port.empty) begin
                        w_buf_state <= TRANSACTION;
                    end
                end

                TRANSACTION: begin
                    if (!w_buf_full) begin
                        if (slv.w_valid) begin
                            w_align_state <= next_w_align_state[MST_ALIGN_BITS-1:0];
                            if (w_align_overflow || slv.w_last) begin
                                w_buf_full <= 1'b1;
                            end
                        end
                    end else begin
                        if (mst.w_ready) begin
                            if (slv.w_valid) begin
                                w_align_state <= next_w_align_state[MST_ALIGN_BITS-1:0];
                            end
                            if (!slv.w_valid || !slv.w_last) begin
                                w_buf_full <= 1'b0;
                            end
                            if (w_last_buf) begin
                                w_buf_state <= IDLE;
                            end
                        end
                    end
                end

            endcase

        end
    end

    always_comb begin
        slv.r_data = mst.r_data[AXI_SLV_DATA_WIDTH-1:0];
        for (int i = 1; i < AXI_MST_DATA_WIDTH/AXI_SLV_DATA_WIDTH; ++i) begin
            if (r_align_state[MST_ALIGN_BITS-1:SLV_ALIGN_BITS] == i[MST_ALIGN_BITS-SLV_ALIGN_BITS-1:0]) begin
                slv.r_data = mst.r_data[i*AXI_SLV_DATA_WIDTH +: AXI_SLV_DATA_WIDTH];
            end
        end
    end

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            r_buf_state <= IDLE;
        end else begin

            case (r_buf_state)

                IDLE: begin
                    if (mst.r_valid) begin
                        r_burst_size <= {{SLV_ALIGN_BITS{1'b0}}, 1'b1} << ar_align_fifo_dout.ar_size;
                        r_align_state <= ar_align_fifo_dout.initial_alignment;
                        r_len <= ar_align_fifo_dout.ar_len;
                        r_buf_state <= TRANSACTION;
                    end
                end

                TRANSACTION: begin
                    if (mst.r_valid) begin
                        if (slv.r_ready) begin
                            r_align_state <= next_r_align_state[MST_ALIGN_BITS-1:0];
                            r_len <= r_len - 8'd1;
                            if (r_len == 8'd0) begin
                                r_buf_state <= IDLE;
                            end
                        end
                    end
                end

            endcase

        end
    end

endmodule
