//`define RANDOM

module axiu_delayer #(
    parameter MAX_OUTSTANDING_AW = 0,
    parameter MAX_OUTSTANDING_W = 0,
    parameter MAX_OUTSTANDING_R = 0,
    parameter READ_LATENCY = 0,
    parameter READ_BANDWIDTH_UP = 1,
    parameter READ_BANDWIDTH_DOWN = 0,
    parameter READ_BANDWIDTH_RAND = 0,
    parameter READ_BANDWIDTH_UP_PROB = 0,
    parameter READ_BANDWIDTH_DOWN_PROB = 0,
    parameter WRITE_LATENCY = 0,
    parameter WRITE_BANDWIDTH_UP = 1,
    parameter WRITE_BANDWIDTH_DOWN = 0,
    parameter WRITE_BANDWIDTH_RAND = 0,
    parameter WRITE_BANDWIDTH_UP_PROB = 0,
    parameter WRITE_BANDWIDTH_DOWN_PROB = 0,
    parameter TIMER_WIDTH = 0
) (
    input clk,
    input arstn,
    AXI_BUS.Slave slv,
    AXI_BUS.Master mst
);

    assign mst.ar_addr   = slv.ar_addr;
    assign mst.ar_burst  = slv.ar_burst;
    assign mst.ar_cache  = slv.ar_cache;
    assign mst.ar_id     = slv.ar_id;
    assign mst.ar_len    = slv.ar_len;
    assign mst.ar_lock   = slv.ar_lock;
    assign mst.ar_prot   = slv.ar_prot;
    assign mst.ar_qos    = slv.ar_qos;
    assign mst.ar_region = slv.ar_region;
    assign mst.ar_size   = slv.ar_size;

    assign mst.aw_addr   = slv.aw_addr;
    assign mst.aw_burst  = slv.aw_burst;
    assign mst.aw_cache  = slv.aw_cache;
    assign mst.aw_id     = slv.aw_id;
    assign mst.aw_len    = slv.aw_len;
    assign mst.aw_lock   = slv.aw_lock;
    assign mst.aw_prot   = slv.aw_prot;
    assign mst.aw_qos    = slv.aw_qos;
    assign mst.aw_region = slv.aw_region;
    assign mst.aw_size   = slv.aw_size;

    assign slv.r_data = mst.r_data;
    assign slv.r_resp = mst.r_resp;
    assign slv.r_last = mst.r_last;
    assign slv.r_id   = mst.r_id;
    assign mst.w_data = slv.w_data;
    assign mst.w_strb = slv.w_strb;
    assign mst.w_last = slv.w_last;
    assign slv.b_resp = mst.b_resp;
    assign slv.b_id   = mst.b_id;

    localparam RU_BANDWIDTH_BITS = READ_BANDWIDTH_UP == 1 ? 1 : $clog2(READ_BANDWIDTH_UP);
    localparam RD_BANDWIDTH_BITS = (READ_BANDWIDTH_DOWN == 0 || READ_BANDWIDTH_DOWN == 1) ? 1 : $clog2(READ_BANDWIDTH_DOWN);
    localparam WU_BANDWIDTH_BITS = WRITE_BANDWIDTH_UP == 1 ? 1 : $clog2(WRITE_BANDWIDTH_UP);
    localparam WD_BANDWIDTH_BITS = (WRITE_BANDWIDTH_DOWN == 0 || WRITE_BANDWIDTH_DOWN == 1) ? 1 : $clog2(WRITE_BANDWIDTH_DOWN);

    AxiUtilsFifo #(.WIDTH(TIMER_WIDTH)) read_fifo_port();
    AxiUtilsFifo #(.WIDTH(TIMER_WIDTH)) aw_fifo_port();
    AxiUtilsFifo #(.WIDTH(TIMER_WIDTH)) w_fifo_port();

    reg [TIMER_WIDTH-1:0] timer;

    typedef enum bit [0:0] {
        READ_DATA,
        READ_DATA_WAIT
    } ReadState_t;

    localparam WRITE_DATA = 0;
    localparam WRITE_DATA_WAIT = 1;

    ReadState_t read_state;
    reg [RU_BANDWIDTH_BITS-1:0] bandwidth_read_up_count;
    reg [RD_BANDWIDTH_BITS-1:0] bandwidth_read_down_count;
    reg [WU_BANDWIDTH_BITS-1:0] bandwidth_write_up_count;
    reg [WD_BANDWIDTH_BITS-1:0] bandwidth_write_down_count;
    reg [0:0] write_state;

    assign mst.ar_valid = !read_fifo_port.full && slv.ar_valid;
    assign slv.ar_ready = !read_fifo_port.full && mst.ar_ready;
    assign read_fifo_port.write = slv.ar_valid && !read_fifo_port.full && mst.ar_ready;
    assign read_fifo_port.din = timer;

    assign mst.r_ready = read_state == READ_DATA && !read_fifo_port.empty && timer >= read_fifo_port.dout+READ_LATENCY && slv.r_ready;
    assign slv.r_valid = read_state == READ_DATA && !read_fifo_port.empty && timer >= read_fifo_port.dout+READ_LATENCY && mst.r_valid;
    assign read_fifo_port.read = read_state == READ_DATA && !read_fifo_port.empty && timer >= read_fifo_port.dout+READ_LATENCY && mst.r_valid && slv.r_ready && mst.r_last;

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            timer <= {TIMER_WIDTH{1'b0}};
        end else begin
            timer <= timer + {{TIMER_WIDTH-1{1'b0}}, 1'b1};
        end
    end

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            read_state <= READ_DATA;
        end else begin

        case (read_state)

            READ_DATA: begin
                bandwidth_read_down_count <= 0;
                if (!read_fifo_port.empty && timer >= read_fifo_port.dout+READ_LATENCY &&
                    mst.r_valid && slv.r_ready && !mst.r_last) begin
                    if (READ_BANDWIDTH_RAND) begin
                        int r;
                        `ifdef RANDOM
                            r = $urandom_range(99);
                        `else
                            r = -1;
                        `endif
                        if (r < READ_BANDWIDTH_DOWN_PROB) begin
                            read_state <= READ_DATA_WAIT;
                        end
                    end else begin
                        if (READ_BANDWIDTH_UP != 1) begin
                            bandwidth_read_up_count <= bandwidth_read_up_count + 1;
                        end
                        if (READ_BANDWIDTH_DOWN != 0) begin
                            if (READ_BANDWIDTH_UP == 1 || bandwidth_read_up_count == READ_BANDWIDTH_UP-1) begin
                                read_state <= READ_DATA_WAIT;
                            end
                        end
                    end
                end
            end

            READ_DATA_WAIT: begin
                if (READ_BANDWIDTH_RAND) begin
                    int r;
                    `ifdef RANDOM
                        r = $urandom_range(99);
                    `else
                        r = -1;
                    `endif
                    if (r < READ_BANDWIDTH_UP_PROB) begin
                        read_state <= READ_DATA;
                    end
                end else begin
                    if (READ_BANDWIDTH_UP != 1) begin
                        bandwidth_read_up_count <= 0;
                    end
                    bandwidth_read_down_count <= bandwidth_read_down_count + 1;
                    if (bandwidth_read_down_count == READ_BANDWIDTH_DOWN-1) begin
                        read_state <= READ_DATA;
                    end
                end
            end

        endcase

        end
    end

    assign mst.aw_valid = !aw_fifo_port.full && slv.aw_valid;
    assign slv.aw_ready = !aw_fifo_port.full && mst.aw_ready;
    assign aw_fifo_port.din = timer;
    assign aw_fifo_port.write = slv.aw_valid && mst.aw_ready && !aw_fifo_port.full;
    assign mst.w_valid = slv.w_valid && !w_fifo_port.full && write_state == WRITE_DATA;
    assign slv.w_ready = mst.w_ready && !w_fifo_port.full && write_state == WRITE_DATA;
    assign w_fifo_port.write = slv.w_valid && mst.w_ready && slv.w_last && !w_fifo_port.full && write_state == WRITE_DATA;
    assign w_fifo_port.din = timer;

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            bandwidth_write_up_count <= 0;
            write_state <= WRITE_DATA;
        end else begin

        case (write_state)

            WRITE_DATA: begin
                bandwidth_write_down_count <= 0;
                if (slv.w_valid && mst.w_ready && !w_fifo_port.full) begin
                    if (WRITE_BANDWIDTH_RAND) begin
                        int r;
                        `ifdef RANDOM
                            r = $urandom_range(99);
                        `else
                            r = -1;
                        `endif
                        if (r < WRITE_BANDWIDTH_DOWN_PROB) begin
                            write_state <= WRITE_DATA_WAIT;
                        end
                    end else begin
                        if (WRITE_BANDWIDTH_UP != 1) begin
                            bandwidth_write_up_count <= bandwidth_write_up_count + 1;
                        end
                        if (WRITE_BANDWIDTH_DOWN != 0) begin
                            if (WRITE_BANDWIDTH_UP == 1 || bandwidth_write_up_count == WRITE_BANDWIDTH_UP-1) begin
                                write_state <= WRITE_DATA_WAIT;
                            end
                        end
                    end
                end
            end

            WRITE_DATA_WAIT: begin
                if (WRITE_BANDWIDTH_RAND) begin
                    int r;
                    `ifdef RANDOM
                        r = $urandom_range(99);
                    `else
                        r = -1;
                    `endif
                    if (r < WRITE_BANDWIDTH_UP_PROB) begin
                        write_state <= WRITE_DATA;
                    end
                end else begin
                    bandwidth_write_up_count <= 0;
                    bandwidth_write_down_count <= bandwidth_write_down_count + 1;
                    if (bandwidth_write_down_count == WRITE_BANDWIDTH_DOWN-1) begin
                        write_state <= WRITE_DATA;
                    end
                end
            end

        endcase

        end
    end

    assign aw_fifo_port.read = mst.b_valid && slv.b_ready && !w_fifo_port.empty && !aw_fifo_port.empty && timer >= w_fifo_port.dout+WRITE_LATENCY && timer >= aw_fifo_port.dout+WRITE_LATENCY;
    assign w_fifo_port.read  = mst.b_valid && slv.b_ready && !w_fifo_port.empty && !aw_fifo_port.empty && timer >= w_fifo_port.dout+WRITE_LATENCY && timer >= aw_fifo_port.dout+WRITE_LATENCY;
    assign mst.b_ready  = !w_fifo_port.empty && timer >= w_fifo_port.dout+WRITE_LATENCY && !aw_fifo_port.empty && timer >= aw_fifo_port.dout+WRITE_LATENCY && slv.b_ready;
    assign slv.b_valid  = !w_fifo_port.empty && timer >= w_fifo_port.dout+WRITE_LATENCY && !aw_fifo_port.empty && timer >= aw_fifo_port.dout+WRITE_LATENCY && mst.b_valid;

    axiu_fifo_fallthrough #(
        .LEN(MAX_OUTSTANDING_R),
        .WIDTH(TIMER_WIDTH)
    ) read_fifo (
        .clk(clk),
        .arstn(arstn),
        .port(read_fifo_port)
    );

    axiu_fifo_fallthrough #(
        .LEN(MAX_OUTSTANDING_AW),
        .WIDTH(TIMER_WIDTH)
    ) aw_fifo (
        .clk(clk),
        .arstn(arstn),
        .port(aw_fifo_port)
    );

    axiu_fifo_fallthrough #(
        .LEN(MAX_OUTSTANDING_W),
        .WIDTH(TIMER_WIDTH)
    ) w_fifo (
        .clk(clk),
        .arstn(arstn),
        .port(w_fifo_port)
    );

endmodule

