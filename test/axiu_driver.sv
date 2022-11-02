
module axiu_driver #(
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_ID_RANGE_LOW = 0,
    parameter AXI_ID_RANGE_HIGH = 0,
    parameter AXI_LEN_RANGE_LOW = 0,
    parameter AXI_LEN_RANGE_HIGH = 255
) (
    input clk,
    input rstn,
    AXI_BUS.Master axi
);

    import AxiUtilsSim::*;

    typedef enum {
        IDLE,
        SEND_ADDR,
        SEND_DATA,
        RECV_DATA,
        WAIT_TIME
    } State_t;

    AddrCmd_t awqueue[$];

    State_t ar_state;
    State_t aw_state;
    State_t w_state;
    State_t r_state;
    State_t b_state;

    function AddrCmd_t genAddrCmd();
        AddrCmd_t cmd;
        cmd.addr = $urandom;
        cmd.id = $urandom_range(AXI_ID_RANGE_LOW, AXI_ID_RANGE_HIGH);
        cmd.len = $urandom_range(AXI_LEN_RANGE_LOW, AXI_LEN_RANGE_HIGH);
        cmd.size = $urandom_range(0, $clog2(AXI_DATA_WIDTH/8));
        cmd.burst = $urandom;
        cmd.lock = $urandom;
        cmd.cache = $urandom;
        cmd.prot = $urandom;
        cmd.qos = $urandom;
        cmd.region = $urandom;

        return cmd;
    endfunction
    
    function int getAlignment(int addr);
        int alignment;
        int mask;
        int bytes_per_word;
        bytes_per_word = AXI_DATA_WIDTH/8;
        mask = -1 << $clog2(bytes_per_word);
        
        return addr & ~mask;
    endfunction
    
    function bit [AXI_DATA_WIDTH-1:0] genRandData();
        bit [AXI_DATA_WIDTH-1:0] data;
        for (int i = 0; i < AXI_DATA_WIDTH; i += 32) begin
            data[i +: 32] = $urandom;
        end
        return data;
    endfunction
    
    function bit [AXI_DATA_WIDTH/8-1:0] genRandWstrb(int alignment, int burst_size);
        bit [AXI_DATA_WIDTH/8-1:0] data;
        int size;
        int alignment_aligned;
        int mask;
        size = 2**burst_size;
        mask = -1 << burst_size;
        alignment_aligned = alignment & mask;
        data = '0;
        for (int i = alignment; i < alignment_aligned+size; ++i) begin
            data[i] = $urandom;
        end
        return data;
    endfunction

    AddrCmd_t current_arcmd;
    AddrCmd_t current_awcmd;
    AddrCmd_t current_wcmd;
    AddrCmd_t current_rcmd;
    AddrCmd_t current_bcmd;
    int ar_count;
    int aw_count;
    int w_count;
    int r_count;
    int b_count;
    int w_strb_alignment;
    reg [AXI_DATA_WIDTH-1:0] wdata;
    reg [AXI_DATA_WIDTH/8-1:0] wstrb;

    assign axi.ar_valid  = ar_state == SEND_ADDR;
    assign axi.ar_addr   = current_arcmd.addr;
    assign axi.ar_id     = current_arcmd.id;
    assign axi.ar_len    = current_arcmd.len;
    assign axi.ar_size   = current_arcmd.size;
    assign axi.ar_burst  = current_arcmd.burst;
    assign axi.ar_lock   = current_arcmd.lock;
    assign axi.ar_cache  = current_arcmd.cache;
    assign axi.ar_prot   = current_arcmd.prot;
    assign axi.ar_qos    = current_arcmd.qos;
    assign axi.ar_region = current_arcmd.region;

    assign axi.aw_valid  = aw_state == SEND_ADDR;
    assign axi.aw_addr   = current_awcmd.addr;
    assign axi.aw_id     = current_awcmd.id;
    assign axi.aw_len    = current_awcmd.len;
    assign axi.aw_size   = current_awcmd.size;
    assign axi.aw_burst  = current_awcmd.burst;
    assign axi.aw_lock   = current_awcmd.lock;
    assign axi.aw_cache  = current_awcmd.cache;
    assign axi.aw_prot   = current_awcmd.prot;
    assign axi.aw_qos    = current_awcmd.qos;
    assign axi.aw_region = current_awcmd.region;

    assign axi.w_valid = w_state == SEND_DATA;
    assign axi.w_data = wdata;
    assign axi.w_strb = wstrb;
    assign axi.w_last = w_count == 0;

    assign axi.b_ready = b_state == RECV_DATA;
    assign axi.r_ready = r_state == RECV_DATA;

    always @(posedge clk) begin

        case (ar_state)

            IDLE: begin
                if (rstn) begin
                    AddrCmd_t addrcmd;
                    addrcmd = genAddrCmd();
                    current_arcmd <= addrcmd;
                    glb_ar_queue.push_back(addrcmd);
                end
                ar_state <= SEND_ADDR;
            end

            SEND_ADDR: begin
                assert (axi.ar_ready !== 1'bX) else begin
                    $error("X in ar ready"); $fatal;
                end
                if (axi.ar_ready) begin
                    AddrCmd_t addrcmd;
                    ar_count = $urandom_range(0, 20);
                    addrcmd = genAddrCmd();
                    current_arcmd <= addrcmd;
                    glb_ar_queue.push_back(addrcmd);
                    if (ar_count != 0) begin
                        ar_state <= WAIT_TIME;
                    end
                end
            end

            WAIT_TIME: begin
                ar_count = ar_count-1;
                if (ar_count == 0) begin
                    ar_state <= SEND_ADDR;
                end
            end

        endcase

        case (aw_state)

            IDLE: begin
                if (rstn) begin
                    AddrCmd_t addrcmd;
                    addrcmd = genAddrCmd();
                    current_awcmd <= addrcmd;
                    glb_aw_queue.push_back(addrcmd);
                    glb_w_addr_queue.push_back(addrcmd);
                    awqueue.push_back(addrcmd);
                end
                aw_state <= SEND_ADDR;
            end

            SEND_ADDR: begin
                assert (axi.aw_ready !== 1'bX) else begin
                    $error("X in aw ready"); $fatal;
                end
                if (axi.aw_ready) begin
                    AddrCmd_t addrcmd;
                    aw_count = $urandom_range(0, 20);
                    addrcmd = genAddrCmd();
                    current_awcmd <= addrcmd;
                    glb_aw_queue.push_back(addrcmd);
                    glb_w_addr_queue.push_back(addrcmd);
                    awqueue.push_back(addrcmd);
                    if (aw_count != 0) begin
                        aw_state <= WAIT_TIME;
                    end
                end
            end

            WAIT_TIME: begin
                aw_count = aw_count-1;
                if (aw_count == 0) begin
                    aw_state <= SEND_ADDR;
                end
            end

        endcase

        case (w_state)

            IDLE: begin
                if (awqueue.size() != 0) begin
                    bit [AXI_DATA_WIDTH-1:0] rand_wdata;
                    bit [AXI_DATA_WIDTH/8-1:0] rand_wstrb;
                    DataBeat_t data_beat;
                    current_wcmd = awqueue.pop_front();
                    w_strb_alignment = getAlignment(current_wcmd.addr);
                    rand_wdata = genRandData();
                    rand_wstrb = genRandWstrb(w_strb_alignment, current_wcmd.size);
                    w_strb_alignment = w_strb_alignment & (-1 << current_wcmd.size);
                    w_count <= current_wcmd.len;
                    data_beat.data = rand_wdata;
                    data_beat.wstrb = rand_wstrb;
                    data_beat.last = current_wcmd.len == 0;
                    glb_w_queue.push_back(data_beat);
                    wdata <= rand_wdata;
                    wstrb <= rand_wstrb;
                    w_state <= SEND_DATA;
                end
            end

            SEND_DATA: begin
                assert (axi.w_ready !== 1'bX) else begin
                    $error("X in w ready"); $fatal;
                end
                if (axi.w_ready) begin
                    w_count <= w_count - 1;
                    if (w_count == 0) begin
                        int r;
                        r = $urandom_range(0, 20);
                        w_count <= r;
                        if (r == 0) begin
                            w_state <= IDLE;
                        end else begin
                            w_state <= WAIT_TIME;
                        end
                    end else begin
                        DataBeat_t data_beat;
                        bit [AXI_DATA_WIDTH/8-1:0] rand_wstrb;
                        w_strb_alignment += 2**current_wcmd.size;
                        if (w_strb_alignment >= AXI_DATA_WIDTH/8) begin
                            bit [AXI_DATA_WIDTH-1:0] rand_wdata;
                            w_strb_alignment = 0;
                            rand_wdata = genRandData();
                            data_beat.data = rand_wdata;
                            wdata <= rand_wdata;
                        end else begin
                            data_beat.data = wdata;
                        end
                        rand_wstrb = genRandWstrb(w_strb_alignment, current_wcmd.size);
                        data_beat.wstrb = rand_wstrb;
                        data_beat.last = w_count == 1;
                        glb_w_queue.push_back(data_beat);
                        wstrb <= rand_wstrb;
                        
                    end
                end
            end

            WAIT_TIME: begin
                w_count <= w_count - 1;
                if (w_count == 1) begin
                    w_state <= IDLE;
                end
            end

        endcase

        case (r_state)

            RECV_DATA: begin
                assert (!rstn || axi.r_valid !== 1'bX) else begin
                    $error("X in r valid"); $fatal;
                end
                if (axi.r_valid) begin
                    DataBeat_t data_beat;
                    assert (glb_r_queue.size() != 0) else begin
                        $error("Unexpected rdata beat"); $fatal;
                    end
                    data_beat = glb_r_queue.pop_front();
                    assert (axi.r_data == data_beat.data[AXI_DATA_WIDTH-1:0]) else begin
                        $error("Wrong rdata beat, expected %0x found %0x", axi.r_data, data_beat.data[AXI_DATA_WIDTH-1:0]); $fatal;
                    end
                    assert (axi.r_id == data_beat.id) else begin
                        $error("Wrong rdata id, expected %0d found %0d", data_beat.id, axi.r_id); $fatal;
                    end
                    assert (axi.r_resp == data_beat.resp) else begin
                        $error("Wrong rdata beat"); $fatal;
                    end
                    assert (axi.r_last == data_beat.last) else begin
                        $error("Wrong rdata beat expected %0d but dound %0d", data_beat.last, axi.r_last); $fatal;
                    end
                    if (axi.r_last) begin
                        int r;
                        r = $urandom_range(0, 20);
                        r_count <= r;
                        if (r == 0) begin
                            r_state <= RECV_DATA;
                        end else begin
                            r_state <= WAIT_TIME;
                        end
                    end
                end
            end

            WAIT_TIME: begin
                r_count <= r_count - 1;
                if (r_count == 1) begin
                    r_state <= RECV_DATA;
                end
            end

        endcase

        case (b_state)

            RECV_DATA: begin
                assert (!rstn || axi.b_valid !== 1'bX) else begin
                    $error("X in b valid"); $fatal;
                end
                if (axi.b_valid) begin
                    WrespBeat_t wresp_beat;
                    assert (glb_b_queue.size() != 0) else begin
                        $error("Reveived unexpected B beat"); $fatal;
                    end
                    wresp_beat = glb_b_queue.pop_front();
                    assert (wresp_beat.id == axi.b_id) else begin
                        $error("Wrong wresp beat, expected %0d found %0d", wresp_beat.id, axi.b_id); $fatal;
                    end
                    assert (wresp_beat.resp == axi.b_resp) else begin
                        $error("Wrong wresp beat"); $fatal;
                    end
                    b_count = $urandom_range(0, 20);
                    if (b_count == 0) begin
                        b_state <= RECV_DATA;
                    end else begin
                        b_state <= WAIT_TIME;
                    end
                end
            end

            WAIT_TIME: begin
                b_count = b_count-1;
                if (b_count == 0) begin
                    b_state <= RECV_DATA;
                end
            end

        endcase

        if (!rstn) begin
            ar_state <= IDLE;
            aw_state <= IDLE;
            w_state  <= IDLE;
            r_state <= RECV_DATA;
            b_state <= RECV_DATA;
        end
    end

endmodule
