
module axiu_dyn_id_alloc_channel #(
    parameter SLV_AXI_ID_WIDTH = 0,
    parameter MST_UNIQUE_IDS = 0,
    parameter MAX_TXNS_PER_ID = 0,
    localparam MST_AXI_ID_WIDTH = $clog2(MST_UNIQUE_IDS)
) (
    input clk,
    input arstn,
    input req_valid,
    input [SLV_AXI_ID_WIDTH-1:0] req_id,
    output logic [MST_AXI_ID_WIDTH-1:0] req_id_mapped,
    output req_ready,
    input resp_valid,
    input [MST_AXI_ID_WIDTH-1:0] resp_id,
    output [SLV_AXI_ID_WIDTH-1:0] resp_id_mapped
);

    localparam MAX_OUTSTANDING_REQ_WIDTH = $clog2(MAX_TXNS_PER_ID+1);

    wire incr_outstanding_req;
    wire decr_outstanding_req;
    wire req_id_match;
    wire [MST_UNIQUE_IDS-1:0] id_fifo_full;
    wire [SLV_AXI_ID_WIDTH-1:0] id_fifo_dout[MST_UNIQUE_IDS];
    logic [MST_AXI_ID_WIDTH-1:0] sel_dyn_id;
    reg [MAX_OUTSTANDING_REQ_WIDTH-1:0] req_id_outstanding_req[2**SLV_AXI_ID_WIDTH];
    reg [MST_AXI_ID_WIDTH-1:0] req_id_map[2**SLV_AXI_ID_WIDTH];
    
    AxiUtilsFifo #(.WIDTH(SLV_AXI_ID_WIDTH)) id_fifo_ports[MST_UNIQUE_IDS]();
    
    reg [MAX_OUTSTANDING_REQ_WIDTH-1:0] fifo_size[MST_UNIQUE_IDS];
    wire [MAX_OUTSANDING_REQ_WIDTH-1:0] min_size_mat[$clog2(MST_UNIQUE_IDS)+1][MST_UNIQUE_IDS];
    
    assign req_id_match = req_id_outstanding_req[req_id] != '0;
    assign resp_id_mapped = id_fifo_dout[resp_id];
    assign req_ready = !(&id_fifo_full) && (!req_id_match || !id_fifo_full[req_id_map[req_id]]);
    
    assign incr_outstanding_req = req_valid && req_ready;
    assign decr_outstanding_req = resp_valid;
    
    for (genvar i = 0; i < MST_UNIQUE_IDS; ++i) begin
        assign min_size_mat[0][i] = fifo_size[i];
    end
    
    for (genvar i = 1; i <= $clog2(MST_UNIQUE_IDS); ++i) begin
        localparam divisor = 2**i;
    
        for (genvar j = 0; j < MST_UNIQUE_IDS/divisor; ++j) begin
            assign min_size_mat[i][j] = min_size_mat[i-1][j*2] < min_size_mat[i-1][j*2+1] ? min_size_mat[i-1][j*2] : min_size_mat[i-1][j*2+1];
        end
    
        if (MST_UNIQUE_IDS%divisor != 0) begin
            assign min_size_mat[i][MST_UNIQUE_IDS/divisor] = min_size_mat[i][(MST_UNIQUE_IDS/divisor)*2];
        end
    
    end
    
    for (genvar i = 0; i < MST_UNIQUE_IDS; ++i) begin : gen_id_fifos
        axiu_fifo_fallthrough #(
            .WIDTH(SLV_AXI_ID_WIDTH),
            .LEN(MAX_TXNS_PER_ID)
        ) id_fifo (
            .clk(clk),
            .arstn(arstn),
            .port(id_fifo_ports[i])
        );
        
        assign id_fifo_full[i] = id_fifo_ports[i].full;
        assign id_fifo_dout[i] = id_fifo_ports[i].dout;
        assign id_fifo_ports[i].din = req_id;
        assign id_fifo_ports[i].read = resp_valid && resp_id == i;
        
        always_comb begin
            id_fifo_ports[i].write = req_valid && !id_fifo_ports[i].full && ((!req_id_match && sel_dyn_id == i) || (req_id_match && req_id_map[req_id] == i));
        end
        
        always_ff @(posedge clk or negedge arstn) begin
            if (!arstn) begin
                fifo_size[i] <= '0;
            end else begin
                if (id_fifo_ports[i].write && !id_fifo_ports[i].read) begin
                    fifo_size[i] <= fifo_size[i] + 1;
                end else if (!id_fifo_ports[i].write && id_fifo_ports[i].read) begin
                    fifo_size[i] <= fifo_size[i] - 1;
                end
            end
        end
    end
    
    always_comb begin
        req_id_mapped = req_id_map[req_id];
        if (!req_id_match) begin
            for (int i = 0; i < MST_UNIQUE_IDS; ++i) begin
                if (!id_fifo_full[i]) begin
                    req_id_mapped = i;
                    break;
                end
            end
        end
    end
    
    always_comb begin
        sel_dyn_id = '0;
        if (id_fifo_full[0]) begin
            for (int i = 1; i < MST_UNIQUE_IDS; ++i) begin
                if (!id_fifo_full[i]) begin
                    sel_dyn_id = i;
                    break;
                end
            end
        end
    end
    
    always_ff @(posedge clk or negedge arstn) begin
        if (!arstn) begin
            for (int i = 0; i < 2**SLV_AXI_ID_WIDTH; ++i) begin
                req_id_outstanding_req[i] <= '0;
            end
        end else begin
            if (req_valid && !req_id_match) begin
                for (int i = 0; i < MST_UNIQUE_IDS; ++i) begin
                    if (!id_fifo_full[i]) begin
                        req_id_map[req_id] <= i;
                        break;
                    end
                end
            end
            if (incr_outstanding_req && (!decr_outstanding_req || req_id != resp_id_mapped)) begin
                req_id_outstanding_req[req_id] <= req_id_outstanding_req[req_id] + 1;
            end
            if (decr_outstanding_req && (!incr_outstanding_req || req_id != resp_id_mapped)) begin
                req_id_outstanding_req[resp_id_mapped] <= req_id_outstanding_req[resp_id_mapped] - 1;
            end
        end
    end

endmodule
