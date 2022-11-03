
module axiu_dwidth_upsizer_check (
    input clk,
    input rstn,
    AXI_BUS.Monitor axi
);

    import AxiUtilsSim::*;

    typedef struct {
        reg [4:0] initial_alignment;
        reg [4:0] burst_size;
        reg [7:0] len;
    } AlignInfo_t;

    typedef struct {
        AlignInfo_t queue[$];
    } IDQueue_t;

    IDQueue_t align_info_dict[int];
    int first_w = 1;
    int first_r = 1;
    int r_len;

    function int get_conv_len(int len, int addr, int burst_size);
        int len_bytes;
        int addr_aligned;
        int mask;
        int total_size;
        mask = -1 << burst_size;

        addr_aligned = addr & mask;
        mask = -1 << 5;
        addr_aligned = addr_aligned & ~mask;
        len_bytes = (len+1)*(2**burst_size);
        total_size = addr_aligned + len_bytes;

        return total_size/32 + (total_size%32 != 0) - 1;
    endfunction

    always @(posedge clk) begin
        if (axi.ar_valid && axi.ar_ready) begin
            AddrCmd_t cmd;
            int conv_len;
            AlignInfo_t align_info;
            assert (glb_ar_queue.size() != 0) else begin
                $error("Received addr command but queue is empty"); $fatal;
            end
            cmd = glb_ar_queue.pop_front();
            align_info.initial_alignment = cmd.addr[4:0];
            align_info.burst_size = 2**cmd.size;
            align_info.len = cmd.len;
            align_info_dict[cmd.id].queue.push_back(align_info);
            assert (cmd.addr == axi.ar_addr) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.id == axi.ar_id) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            conv_len = get_conv_len(cmd.len, cmd.addr, cmd.size);
            assert (conv_len == axi.ar_len) else begin
                $error("Wrong addr cmd, expected len %0d but found %0d", conv_len, axi.ar_len); $fatal;
            end
            assert (5 == axi.ar_size) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.burst == axi.ar_burst) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.lock == axi.ar_lock) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.cache == axi.ar_cache) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.prot == axi.ar_prot) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.qos == axi.ar_qos) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.region == axi.ar_region) else begin
                $error("Wrong addr cmd"); $fatal;
            end
        end

        if (axi.aw_valid && axi.aw_ready) begin
            AddrCmd_t cmd;
            int conv_len;
            assert (glb_aw_queue.size() != 0) else begin
                $error("Received addr command but queue is empty"); $fatal;
            end
            cmd = glb_aw_queue.pop_front();
            assert (cmd.addr == axi.aw_addr) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.id == axi.aw_id) else begin
                $error("Wrong addr cmd id, expected %0d found %0d", cmd.id, axi.aw_id); $fatal;
            end
            conv_len = get_conv_len(cmd.len, cmd.addr, cmd.size);
            assert (conv_len == axi.aw_len) else begin
                $error("Wrong addr cmd, expented len %0d found %0d", conv_len, axi.aw_len); $fatal;
            end
            assert (5 == axi.aw_size) else begin
                $error("Wrong addr cmd expected %0d found %0d", cmd.size, axi.aw_size); $fatal;
            end
            assert (cmd.burst == axi.aw_burst) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.lock == axi.aw_lock) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.cache == axi.aw_cache) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.prot == axi.aw_prot) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.qos == axi.aw_qos) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            assert (cmd.region == axi.aw_region) else begin
                $error("Wrong addr cmd"); $fatal;
            end
        end

        if (axi.w_valid && axi.w_ready) begin
            AddrCmd_t addrcmd;
            int align_state;
            int burst_size;
            reg [31:0] wstrb;
            reg [127:0] bit_wstrb;
            DataBeat_t data_beat;
            assert (glb_w_addr_queue.size() != 0) else begin
                $error("Unexpected w data transfer"); $fatal;
            end
            addrcmd = glb_w_addr_queue[0];
            burst_size = 2**addrcmd.size;
            if (first_w) begin
                first_w = 0;
                align_state = addrcmd.addr[4:0];
            end else begin
                align_state = 0;
            end
            wstrb = 0;
            while (align_state < 32) begin
                assert (glb_w_queue.size() != 0) else begin
                    $error("Received data command but queue is empty"); $fatal;
                end
                data_beat = glb_w_queue.pop_front();
                for (int i = 0; i < 128; i += 8) begin
                    bit_wstrb[i +: 8] = {8{data_beat.wstrb[i/8]}};
                end
                if (align_state < 16) begin
                    assert ((data_beat.data & bit_wstrb) == (axi.w_data[127:0] & bit_wstrb)) else begin
                        $error("data_beat data  %0x wstrb %0x, axi_wdata %0x", data_beat.data, bit_wstrb, axi.w_data[127:0]);
                        $error("Incorrect w data transfer, expected %0x found %0x", data_beat.data & bit_wstrb, axi.w_data[127:0] & bit_wstrb); $fatal;
                    end
                    wstrb[15:0] = wstrb[15:0] | data_beat.wstrb;
                end else begin
                    assert ((data_beat.data & bit_wstrb) == (axi.w_data[255:128] & bit_wstrb)) else begin
                        $error("Incorrect w data transfer, expected %0x found %0d", data_beat.data & bit_wstrb, axi.w_data[255:128] & bit_wstrb); $fatal;
                    end
                    wstrb[31:16] = wstrb[31:16] | data_beat.wstrb;
                end
                if (data_beat.last) begin
                    first_w = 1;
                    glb_w_addr_queue.pop_front();
                    break;
                end
                align_state += burst_size;
            end
            assert (wstrb == axi.w_strb) else begin
                $error("Incorrect w data transfer"); $fatal;
            end
            assert (data_beat.last == axi.w_last) else begin
                $error("Incorrect w data transfer, expected lasr %0d found %0d", data_beat.last, axi.w_last); $fatal;
            end
        end

        if (axi.r_valid && axi.r_ready) begin
            AlignInfo_t align_info;
            int align_state;
            int burst_size;
            align_info = align_info_dict[axi.r_id].queue[0];
            burst_size = align_info.burst_size;
            if (first_r) begin
                first_r = 0;
                r_len = align_info.len;
                align_state = align_info.initial_alignment;
            end else begin
                align_state = 0;
            end
            while (align_state < 32) begin
                DataBeat_t data_beat;
                if (align_state < 16)  begin
                    data_beat.data = axi.r_data[127:0];
                end else begin
                    data_beat.data = axi.r_data[255:128];
                end
                data_beat.last = r_len == 0;
                data_beat.resp = axi.r_resp;
                data_beat.id = axi.r_id;
                glb_r_queue.push_back(data_beat);
                if (r_len == 0) begin
                    first_r = 1;
                    align_info_dict[axi.r_id].queue.pop_front();
                    if (align_info_dict[axi.r_id].queue.size() == 0) begin
                        align_info_dict.delete(axi.r_id);
                    end
                    break;
                end
                r_len -= 1;
                align_state += burst_size;
            end
            assert (first_r == axi.r_last) else begin
                $error("Something went wrong with the last signal, first_r %0d last %0d", first_r, axi.r_last); $fatal;
            end
        end

        if (axi.b_valid && axi.b_ready) begin
            WrespBeat_t wresp_beat;
            wresp_beat.id = axi.b_id;
            wresp_beat.resp = axi.b_resp;
            glb_b_queue.push_back(wresp_beat);
        end
    end

endmodule
