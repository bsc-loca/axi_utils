`timescale 1 ns / 1 ps

module axiu_stub #(
    parameter MAX_OUTSTANDING_AW = 0,
    parameter MAX_OUTSTANDING_W = 0,
    parameter MAX_OUTSTANDING_R = 0,
    parameter AXI_ID_WIDTH = 0,
    parameter AXI_DATA_WIDTH = 0,
    parameter AXI_ADDR_WIDTH = 0,
    parameter RANDOMIZE_RDATA = 0,
    parameter RANDOMIZE_RESP = 0
) (
    input  clk,
    input  arstn,
    AXI_BUS.Slave slv
);

    bit [AXI_DATA_WIDTH-1:0] rdata;
    bit [1:0] rresp;
    bit [1:0] bresp;

    if (RANDOMIZE_RESP) begin
        assign slv.b_resp = slv.b_valid ? bresp : 2'dX;
        assign slv.r_resp = slv.r_valid ? rresp : 2'dX;
    end else begin
        assign slv.b_resp = slv.b_valid ? 2'd0 : 2'dX;
        assign slv.r_resp = slv.r_valid ? 2'd0 : 2'dX;
    end

    if (RANDOMIZE_RDATA) begin
        assign slv.r_data = slv.r_valid ? rdata : {AXI_DATA_WIDTH{1'bX}};
    end else begin
        assign slv.r_data = slv.r_valid ? {AXI_DATA_WIDTH{1'b0}} : {AXI_DATA_WIDTH{1'bX}};
    end

    wire read_fifo_full;
    wire read_fifo_wr_en;

    wire read_fifo_empty;
    wire [7:0] read_fifo_dout;
    wire [AXI_ID_WIDTH-1:0] read_fifo_id_out;
    wire read_fifo_rd_en;

    wire aw_fifo_full;
    wire aw_fifo_wr_en;

    wire aw_fifo_empty;
    wire [AXI_ID_WIDTH-1:0] aw_fifo_id_out;
    wire aw_fifo_rd_en;

    AxiUtilsFifo #(.WIDTH(1)) w_fifo();
    
    reg [7:0] read_count;

    assign slv.ar_ready = !read_fifo_full;
    assign read_fifo_wr_en = slv.ar_valid && slv.ar_ready;
    assign slv.r_id = slv.r_valid ? read_fifo_id_out : {AXI_ID_WIDTH{1'bX}};

    assign slv.r_valid = !read_fifo_empty;
    assign slv.r_last = slv.r_valid ? read_count == read_fifo_dout : 1'bX;
    assign read_fifo_rd_en = !read_fifo_empty && slv.r_ready && (read_count == read_fifo_dout);

    if (RANDOMIZE_RDATA) begin
        for (genvar i = 0; i < AXI_DATA_WIDTH; i += 32) begin
            always_ff @(posedge clk, negedge arstn) begin
                if ((read_fifo_empty && read_fifo_wr_en) || (!read_fifo_empty && slv.r_ready)) begin
                    if (i+32 > AXI_DATA_WIDTH) begin
                        rdata[AXI_DATA_WIDTH-1:i] <= $urandom;
                    end else begin
                        rdata[i +: 32] <= $urandom;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            read_count <= 7'd0;
        end else begin
            if (read_fifo_empty && read_fifo_wr_en) begin
                rresp <= $urandom;
            end else if (!read_fifo_empty && slv.r_ready) begin
                if (RANDOMIZE_RESP) begin
                    rresp <= $urandom;
                end
                if (read_count == read_fifo_dout[7:0]) begin
                    read_count <= 7'd0;
                end else begin
                    read_count <= read_count + 7'd1;
                end
            end
        end
    end

    assign slv.aw_ready = !aw_fifo_full;
    assign slv.w_ready = !w_fifo.full;
    assign aw_fifo_wr_en = slv.aw_valid && slv.aw_ready;
    assign w_fifo.write = slv.w_valid && slv.w_ready && slv.w_last;
    assign slv.b_id = slv.b_valid ? aw_fifo_id_out : {AXI_ID_WIDTH{1'bX}};

    assign aw_fifo_rd_en = !aw_fifo_empty && !w_fifo.empty && slv.b_ready;
    assign w_fifo.read = !aw_fifo_empty && !w_fifo.empty && slv.b_ready;
    assign slv.b_valid = !aw_fifo_empty && !w_fifo.empty;

    if (RANDOMIZE_RESP) begin
        always_ff @(posedge clk) begin
            if ((aw_fifo_empty && aw_fifo_wr_en) || aw_fifo_rd_en) begin
                bresp <= $urandom;
            end
        end
    end
    
    axiu_reorder_buffer_fallthrough #(
        .LEN(MAX_OUTSTANDING_R),
        .WIDTH(8),
        .ID_WIDTH(AXI_ID_WIDTH)
    ) read_fifo_I (
        .clk(clk),
        .arstn(arstn),
        .full(read_fifo_full),
        .write(read_fifo_wr_en),
        .id_in(slv.ar_id),
        .din(slv.ar_len),
        .empty(read_fifo_empty),
        .read(read_fifo_rd_en),
        .dout(read_fifo_dout),
        .id_out(read_fifo_id_out)
    );

    axiu_reorder_buffer_fallthrough #(
        .LEN(MAX_OUTSTANDING_AW),
        .WIDTH(1),
        .ID_WIDTH(AXI_ID_WIDTH)
    ) aw_fifo_I (
        .clk(clk),
        .arstn(arstn),
        .full(aw_fifo_full),
        .write(aw_fifo_wr_en),
        .id_in(slv.aw_id),
        .din(1'b0),
        .empty(aw_fifo_empty),
        .read(aw_fifo_rd_en),
        .dout(),
        .id_out(aw_fifo_id_out)
    );
    
    axiu_fifo_fallthrough #(
        .LEN(MAX_OUTSTANDING_W),
        .WIDTH(1)
    ) w_fifo_I (
        .clk(clk),
        .arstn(arstn),
        .port(w_fifo)
    );

endmodule