
module axiu_axilite_to_memport #(
    parameter ADDR_WIDTH = 0
) (
    input clk,
    input rst,
    AXI_LITE.Slave axilite_port,
    output logic memport_en,
    output logic memport_we,
    output logic [ADDR_WIDTH-1:0] memport_addr,
    output logic [31:0] memport_din,
    input  [31:0] memport_dout

);

    typedef enum bit [1:0] {
        IDLE,
        READ,
        WRITE_DATA,
        WRITE_RESP
    } State_t;

    State_t state;

    reg arb_read;

    reg [ADDR_WIDTH-1:0] awaddr_buffer;
    reg [ADDR_WIDTH-1:0] awaddr_buffer_2;
    reg buffer_2_full;
    wire [ADDR_WIDTH-1:0] ar_mem_addr;
    wire [ADDR_WIDTH-1:0] aw_mem_addr;

    assign ar_mem_addr = axilite_port.ar_addr[2 +: ADDR_WIDTH];
    assign aw_mem_addr = axilite_port.aw_addr[2 +: ADDR_WIDTH];

    assign memport_din = axilite_port.w_data;

    assign axilite_port.r_data = memport_dout;
    assign axilite_port.r_resp = 2'd0;
    assign axilite_port.b_resp = 2'd0;

    always_comb begin

        axilite_port.ar_ready = 1'b0;
        axilite_port.r_valid = 1'b0;
        axilite_port.aw_ready = 1'b0;
        axilite_port.w_ready = 1'b0;
        axilite_port.b_valid = 1'b0;

        memport_en = 1'b0;
        memport_we = 1'b0;
        memport_addr = awaddr_buffer; //WRITE_DATA state

        case (state)

            IDLE: begin
                memport_en = (axilite_port.ar_valid && (!axilite_port.aw_valid || arb_read)) || (axilite_port.aw_valid && axilite_port.w_valid);
                if (axilite_port.ar_valid && (!axilite_port.aw_valid || arb_read)) begin
                    memport_addr = ar_mem_addr;
                    axilite_port.ar_ready = 1'b1;
                end else begin
                    memport_addr = aw_mem_addr;
                    memport_we = axilite_port.w_valid;
                    axilite_port.aw_ready = 1'b1;
                    axilite_port.w_ready = axilite_port.aw_valid;
                end
            end

            READ: begin
                axilite_port.r_valid = 1'b1;
                memport_addr = axilite_port.aw_valid ? aw_mem_addr : ar_mem_addr;
                if (axilite_port.r_ready) begin
                    memport_en = (axilite_port.ar_valid && !axilite_port.aw_valid) || (axilite_port.aw_valid && axilite_port.w_valid);
                    if (!axilite_port.aw_valid) begin
                        axilite_port.ar_ready = 1'b1;
                    end else begin
                        memport_we = axilite_port.w_valid;
                        axilite_port.aw_ready = 1'b1;
                        axilite_port.w_ready = 1'b1;
                    end
                end
            end

            WRITE_DATA: begin
                memport_en = axilite_port.w_valid;
                memport_we = 1'b1;
                axilite_port.aw_ready = !buffer_2_full && !axilite_port.ar_valid;
                axilite_port.w_ready = 1'b1;
            end

            WRITE_RESP: begin
                axilite_port.b_valid = 1'b1;
                memport_addr = (axilite_port.ar_valid && !buffer_2_full) ? ar_mem_addr : (buffer_2_full ? awaddr_buffer_2 : aw_mem_addr);
                if (axilite_port.b_ready) begin
                    memport_en = (!buffer_2_full && axilite_port.ar_valid) || ((axilite_port.aw_valid || buffer_2_full) && axilite_port.w_valid); //this can be optimized
                    if (!axilite_port.ar_valid || buffer_2_full) begin
                        memport_we = axilite_port.w_valid;
                        axilite_port.aw_ready = !axilite_port.ar_valid;
                        axilite_port.w_ready = axilite_port.aw_valid || buffer_2_full;
                    end else begin
                        axilite_port.ar_ready = 1'b1;
                    end
                end
            end

        endcase

    end

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                awaddr_buffer <= aw_mem_addr;
                buffer_2_full <= 1'b0;
                if (axilite_port.ar_valid && (!axilite_port.aw_valid || arb_read)) begin
                    state <= READ;
                end else if (axilite_port.aw_valid) begin
                    if (axilite_port.w_valid) begin
                        state <= WRITE_RESP;
                    end else begin
                        state <= WRITE_DATA;
                    end
                end
            end

            READ: begin
                arb_read <= 1'b0;
                awaddr_buffer <= aw_mem_addr;
                if (axilite_port.r_ready) begin
                    if (axilite_port.aw_valid) begin
                        if (axilite_port.w_valid) begin
                            state <= WRITE_RESP;
                        end else begin
                            state <= WRITE_DATA;
                        end
                    end else if (!axilite_port.ar_valid) begin
                        state <= IDLE;
                    end
                end
            end

            WRITE_DATA: begin
                if (!buffer_2_full) begin
                    awaddr_buffer_2 <= aw_mem_addr;
                    if (!axilite_port.ar_valid && axilite_port.aw_valid) begin
                        buffer_2_full <= 1'b1;
                    end
                end
                if (axilite_port.w_valid) begin
                    state <= WRITE_RESP;
                end
            end

            WRITE_RESP: begin
                arb_read <= 1'b1;
                if (buffer_2_full) begin
                    awaddr_buffer <= awaddr_buffer_2;
                end else begin
                    awaddr_buffer <= aw_mem_addr;
                end
                if (axilite_port.b_ready) begin
                    awaddr_buffer_2 <= aw_mem_addr;
                    if (buffer_2_full && !axilite_port.ar_valid && axilite_port.aw_valid) begin
                        buffer_2_full <= 1'b1;
                    end else begin
                        buffer_2_full <= 1'b0;
                    end
                    if (!buffer_2_full && axilite_port.ar_valid) begin
                        state <= READ;
                    end else if (buffer_2_full || axilite_port.aw_valid) begin
                        if (axilite_port.w_valid) begin
                            state <= WRITE_RESP;
                        end else begin
                            state <= WRITE_DATA;
                        end
                    end else begin
                        state <= IDLE;
                    end
                end
            end

        endcase

        if (rst) begin
            arb_read <= 1'b0;
            state <= IDLE;
        end
    end

endmodule
