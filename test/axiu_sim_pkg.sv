package AxiUtilsSim;

    typedef struct {
        bit [63:0] addr;
        bit [31:0] id;
        bit [7:0] len;
        bit [2:0] size;
        bit [1:0] burst;
        bit [0:0] lock;
        bit [3:0] cache;
        bit [2:0] prot;
        bit [3:0] qos;
        bit [3:0] region;
    } AddrCmd_t;

    typedef struct {
        bit [1023:0] data;
        bit [127:0] wstrb;
        bit [1:0] resp;
        bit [31:0] id;
        bit last;
    } DataBeat_t;

    typedef struct {
        bit [31:0] id;
        bit [1:0] resp;
    } WrespBeat_t;

    AddrCmd_t glb_ar_queue[$];
    AddrCmd_t glb_aw_queue[$];
    AddrCmd_t glb_w_addr_queue[$];
    DataBeat_t glb_w_queue[$];
    DataBeat_t glb_r_queue[$];
    WrespBeat_t glb_b_queue[$];

endpackage
