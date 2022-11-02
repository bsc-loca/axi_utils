
module axiu_dyn_id_alloc_check #(
    parameter SLV_AXI_ID_WIDTH = 0,
    parameter MST_UNIQUE_IDS = 0
) (
    input clk,
    input rstn,
    AXI_BUS.Monitor axi
);

    import AxiUtilsSim::*;
    
    typedef struct {
        int q[$];
    } Queue_t;
    
    Queue_t r_id_queues[MST_UNIQUE_IDS];
    int r_id_map[2**SLV_AXI_ID_WIDTH];
    int r_outstanding_id_req[2**SLV_AXI_ID_WIDTH];

    Queue_t w_id_queues[MST_UNIQUE_IDS];
    int w_id_map[2**SLV_AXI_ID_WIDTH];
    int w_outstanding_id_req[2**SLV_AXI_ID_WIDTH];

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
            assert (r_outstanding_id_req[cmd.id] == 0 || r_id_map[cmd.id] == axi.ar_id) else begin
                $error("Same original ID mapped to two different outstanding IDs"); $fatal;
            end
            
            ++r_outstanding_id_req[cmd.id];
            r_id_queues[axi.ar_id].q.push_back(cmd.id);
            r_id_map[cmd.id] = axi.ar_id;
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
            assert (w_outstanding_id_req[cmd.id] == 0 || w_id_map[cmd.id] == axi.aw_id) else begin
                $error("Same original ID mapped to two different outstanding IDs"); $fatal;
            end

            ++w_outstanding_id_req[cmd.id];
            w_id_queues[axi.aw_id].q.push_back(cmd.id);
            w_id_map[cmd.id] = axi.aw_id;
        end
        if (axi.r_valid && axi.r_ready) begin
            DataBeat_t data_beat;
            data_beat.data = axi.r_data;
            data_beat.resp = axi.r_resp;
            data_beat.last = axi.r_last;
            data_beat.id = r_id_queues[axi.r_id].q[0];
            glb_r_queue.push_back(data_beat);
            
            if (axi.r_last) begin
                --r_outstanding_id_req[r_id_queues[axi.r_id].q[0]];
                r_id_queues[axi.r_id].q.pop_front();
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
            WrespBeat_t wresp_beat;
            wresp_beat.id = w_id_queues[axi.b_id].q[0];
            wresp_beat.resp = axi.b_resp;
            glb_b_queue.push_back(wresp_beat);
            --w_outstanding_id_req[w_id_queues[axi.b_id].q[0]];
            w_id_queues[axi.b_id].q.pop_front();
        end
    end

endmodule
