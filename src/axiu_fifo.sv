
module axiu_fifo #(
    parameter WIDTH = 0,
    parameter LEN = 0,
    parameter MEM_MACRO = 1'b0
) (
    input clk,
    input arstn,
    AxiUtilsFifo.slave port
);

    `ifndef FPGA
        `ifndef VERILATOR
            localparam USE_MACRO = MEM_MACRO;
        `else
            localparam USE_MACRO = 1'b0;
        `endif //`ifndef FPGA
    `else
        localparam USE_MACRO = 1'b0;
    `endif //`ifndef VERILATOR

    localparam CLOG2LEN = $clog2(LEN);
    localparam LAST_IDX = LEN-1;
    localparam CLOG2LEN_0 = {CLOG2LEN{1'b0}};
    localparam CLOG2LEN_1 = {{CLOG2LEN-1{1'b0}}, 1'b1};
    localparam IDX_0 = {CLOG2LEN+1{1'b0}};
    localparam IDX_1 = {{CLOG2LEN{1'b0}}, 1'b1};
    localparam POWER_2 = (LEN & (LEN-1)) == 0;

    reg [CLOG2LEN:0] read_idx;
    reg [CLOG2LEN:0] write_idx;

    assign port.empty = read_idx == write_idx;
    assign port.full = read_idx[CLOG2LEN-1:0] == write_idx[CLOG2LEN-1:0] && read_idx[CLOG2LEN] != write_idx[CLOG2LEN];

    always_ff @(posedge clk, negedge arstn) begin
        if (!arstn) begin
            read_idx <= IDX_0;
            write_idx <= IDX_0;
        end else begin
            if (port.read) begin
                if (POWER_2) begin
                    read_idx <= read_idx + IDX_1;
                end else begin
                    if (read_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) begin
                        read_idx[CLOG2LEN-1:0] <= CLOG2LEN_0;
                        read_idx[CLOG2LEN] <= !read_idx[CLOG2LEN];
                    end else begin
                        read_idx[CLOG2LEN-1:0] <= read_idx[CLOG2LEN-1:0] + CLOG2LEN_1;
                    end
                end
            end
            if (port.write) begin
                if (POWER_2) begin
                    write_idx <= write_idx + IDX_1;
                end else begin
                    if (write_idx[CLOG2LEN-1:0] == LAST_IDX[CLOG2LEN-1:0]) begin
                        write_idx[CLOG2LEN-1:0] <= CLOG2LEN_0;
                        write_idx[CLOG2LEN] <= !write_idx[CLOG2LEN];
                    end else begin
                        write_idx[CLOG2LEN-1:0] <= write_idx[CLOG2LEN-1:0] + CLOG2LEN_1;
                    end
                end
            end
        end
    end

    generate
    // If a macro must NOT be used, create the FF-based memory
    if (!USE_MACRO) begin

        reg [WIDTH-1:0] mem[LEN];
        always_ff @(posedge clk) begin
            if (port.read) begin
                port.dout <= mem[read_idx[CLOG2LEN-1:0]];
            end
            if (port.write) begin
                mem[write_idx[CLOG2LEN-1:0]] <= port.din;
            end
        end

    // If a macro MUST be used
    end else begin

        mem2p_cascade_wrapper #(
            .DEPTH(LEN),
            .DATA_W(WIDTH)
        ) mem_cascade_i (
            .i_clk          (clk),
            .i_rstn         (arstn),
            .i_deepsleep    ('0),
            .i_powergate    ('0),
            .i_cen_A        (!port.read),      // A is for reading
            .i_addr_A       (read_idx[CLOG2LEN-1:0]),
            .o_outdata_A    (port.dout),
            .i_cen_B        (!port.write),  // B is for writing
            .i_addr_B       (write_idx[CLOG2LEN-1:0]),
            .i_indata_B     (port.din),
            .i_wmask_B      ('1)
        );

    end
    endgenerate

endmodule

