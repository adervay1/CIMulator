package CIMulator_PKG;

localparam CIM_ADDRESS_DEPTH = 256;
localparam CIM_ADDR_WIDTH = 8;
localparam CIM_ADDR_AV_WIDTH = CIM_ADDR_WIDTH + 1;

endpackage


package CIM_INST_PKG;

localparam      OP_FIELD_WIDTH      = 8;
localparam      CIM_ADDR_BITS       = 8;

localparam OP_H = 31;
localparam OP_L = 24;
localparam S1_H = 23;
localparam S1_L = 16;
localparam S2_H = 15;
localparam S2_L = 8;
localparam D1_H = 7;
localparam D1_L = 0;

 typedef struct packed {
    bit [OP_FIELD_WIDTH-1:0]    op;
    bit [CIM_ADDR_BITS-1:0]     s1;
    bit [CIM_ADDR_BITS-1:0]     s2;
    bit [CIM_ADDR_BITS-1:0]     d1;
} cim_field_struct;

endpackage