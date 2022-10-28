interface AxiUtilsFifo #(parameter WIDTH = 0);

    logic read;
    logic write;
    logic [WIDTH-1:0] din;
    logic [WIDTH-1:0] dout;
    logic empty;
    logic full;
    
    modport master(output read, output write, output din, input dout, input empty, input full);
    modport slave(input read, input write, input din, output dout, output empty, output full);

endinterface

