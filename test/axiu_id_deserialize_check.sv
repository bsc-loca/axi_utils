
module axiu_id_deserialize_check #(
    parameter MST_UNIQUE_IDS = 0
) (
    input clk,
    input rstn,
    AXI_BUS.Monitor axi
);

    import AxiUtilsSim::*;
    
    localparam AXI_ID_WIDTH = $clog2(MST_UNIQUE_IDS);
    
    typedef struct {
        DataBeat_t q[$];
    } RQueue_t;
    
    typedef struct {
        int q[$];
    } WQueue_t;
    
    int r_id_fifo[$];
    int w_id_fifo[$];
    
    RQueue_t rdata_fifo[MST_UNIQUE_IDS];
    WQueue_t wdata_fifo[MST_UNIQUE_IDS];
    
    always_ff @(posedge clk) begin
        assert (!rstn || (axi.ar_valid !== 1'bX && axi.aw_valid !== 1'bX && axi.w_valid !== 1'bX && axi.r_ready !== 1'bX && axi.b_ready !== 1'bX)) else begin
            $error("X in ar valid"); $fatal;
        end
        if (axi.ar_valid && axi.ar_ready) begin
            AddrCmd_t cmd;
            assert (glb_ar_queue.size() != 0) else begin
                $error("Received addr command but queue is empty"); $fatal;
            end
            
            cmd = glb_ar_queue.pop_front();
            assert (cmd.addr   == axi.ar_addr &&
                    cmd.len    == axi.ar_len &&
                    cmd.burst  == axi.ar_burst &&
                    cmd.lock   == axi.ar_lock &&
                    cmd.cache  == axi.ar_cache &&
                    cmd.prot   == axi.ar_prot &&
                    cmd.qos    == axi.ar_qos &&
                    cmd.region == axi.ar_region) else begin
                $error("Wrong addr cmd"); $fatal;
            end
            
            assert (axi.ar_id < MST_UNIQUE_IDS) else begin
                $error("Invalid id"); $fatal;
            end
            r_id_fifo.push_back(axi.ar_id);
        end
        if (axi.aw_valid && axi.aw_ready) begin
            AddrCmd_t cmd;
            assert (glb_aw_queue.size() != 0) else begin
                $error("Received addr command but queue is empty"); $fatal;
            end
            
            cmd = glb_aw_queue.pop_front();
            glb_w_addr_queue.pop_front();
            assert (cmd.addr   == axi.aw_addr &&
                    cmd.len    == axi.aw_len &&
                    cmd.burst  == axi.aw_burst &&
                    cmd.lock   == axi.aw_lock &&
                    cmd.cache  == axi.aw_cache &&
                    cmd.prot   == axi.aw_prot &&
                    cmd.qos    == axi.aw_qos &&
                    cmd.region == axi.aw_region) else begin
                $error("Wrong addr cmd"); $fatal;
            end

            assert (axi.aw_id < MST_UNIQUE_IDS) else begin
                $error("Invalid id"); $fatal;
            end
            
            w_id_fifo.push_back(axi.aw_id);
        end
        if (axi.r_valid && axi.r_ready) begin
            DataBeat_t data_beat;
            data_beat.data = axi.r_data;
            data_beat.resp = axi.r_resp;
            data_beat.last = axi.r_last;
            rdata_fifo[axi.r_id].q.push_back(data_beat);
        end
        if (r_id_fifo.size() != 0 && rdata_fifo[r_id_fifo[0]].q.size() != 0) begin
            DataBeat_t data_beat;
            data_beat = rdata_fifo[r_id_fifo[0]].q.pop_front();
            data_beat.id = 0;
            glb_r_queue.push_back(data_beat);
            if (data_beat.last) begin
                r_id_fifo.pop_front();
            end
        end
        if (axi.w_valid && axi.w_ready) begin
            DataBeat_t data_beat;
            data_beat = glb_w_queue.pop_front();
            assert (data_beat.data == axi.w_data &&
                    data_beat.wstrb == axi.w_strb &&
                    data_beat.last == axi.w_last) else begin
               $error("Invalid W channel data"); $fatal;     
            end
        end
        if (axi.b_valid && axi.b_ready) begin
            wdata_fifo[axi.b_id].q.push_back(axi.b_resp);
        end
        if (w_id_fifo.size() != 0 && wdata_fifo[w_id_fifo[0]].q.size() != 0) begin
            WrespBeat_t wresp_beat;
            wresp_beat.resp = wdata_fifo[w_id_fifo[0]].q.pop_front();
            wresp_beat.id = 0;
            glb_b_queue.push_back(wresp_beat);
            w_id_fifo.pop_front();
        end
    end

endmodule
