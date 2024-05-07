package CIMulator_PKG;

localparam CIM_ADDRESS_DEPTH = 512;
localparam CIM_ADDR_WIDTH = 9;
localparam CIM_ADDR_AV_WIDTH = CIM_ADDR_WIDTH + 1;

endpackage


package CIM_INST_PKG;

localparam      OP_FIELD_WIDTH      = 5;
localparam      CIM_ADDR_BITS       = 9;

localparam OP_H = 31;
localparam OP_L = 27;
localparam S1_H = 26;
localparam S1_L = 18;
localparam S2_H = 17;
localparam S2_L = 9;
localparam D1_H = 8;
localparam D1_L = 0;

 typedef struct packed {
    bit [OP_FIELD_WIDTH-1:0]    op;
    bit [CIM_ADDR_BITS-1:0]     s1;
    bit [CIM_ADDR_BITS-1:0]     s2;
    bit [CIM_ADDR_BITS-1:0]     d1;
} cim_field_struct;

endpackage