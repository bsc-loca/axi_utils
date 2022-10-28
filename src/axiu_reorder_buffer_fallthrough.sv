
module axiu_reorder_buffer_fallthrough #(
    parameter LEN = 0,
    parameter WIDTH = 0,
    parameter ID_WIDTH = 0
) (
    input clk,
    input arstn,
    output full,
    input write,
    input [ID_WIDTH-1:0] id_in,
    input [WIDTH-1:0] din,
    output empty,
    input read,
    output reg [WIDTH-1:0] dout,
    output [ID_WIDTH-1:0] id_out
);

    typedef struct {
        reg [WIDTH-1:0] queue[$];
    } IDQueue_t;

    int size = 0;
    reg [ID_WIDTH-1:0] rand_id;
    
    int rand_idx;
    bit [ID_WIDTH-1:0] id_set[$];
    IDQueue_t dict[int];
    
    assign full = size == LEN;
    assign empty = size == 0;
    assign id_out = rand_id;

    always @(posedge clk) begin
        if (write) begin
            if (empty) begin
                rand_idx = 0;
                rand_id = id_in;
                dout <= din;
            end
            size += 1;
            if (!dict.exists(id_in)) begin
                id_set.push_back(id_in);
            end
            dict[id_in].queue.push_back(din);
        end
        if (read) begin
            size -= 1;
            dict[rand_id].queue.pop_front();
            if (dict[rand_id].queue.size() == 0) begin
                dict.delete(rand_id);
                id_set.delete(rand_idx);
            end
            if (!empty) begin
                rand_idx = $urandom_range(id_set.size()-1);
                rand_id = id_set[rand_idx];
                dout <= dict[rand_id].queue[0];
            end
        end
    end

endmodule
