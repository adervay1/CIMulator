module prime_datapath (
    input           sys_clk_in,
    input           sys_reset_in,
    
    output          IMC_mm_waitrequest_out,
    output [31:0]   IMC_mm_readdata_out,
    output          IMC_mm_readdatavalid_out,

    input [31:0]    IMC_mm_writedata_in,
    input [8:0]     IMC_mm_address_in,
    input           IMC_mm_write_in,
    input           IMC_mm_read_in
);


localparam PC_WIDTH         = 12;
localparam INST_ROM_DEPTH   = 2**PC_WIDTH;

logic [31:0] bitline_a;
logic [31:0] bitline_a_n;
logic [31:0] bitline_b;
logic [31:0] bitline_b_n;

logic [31:0] bitline_logical;
logic [31:0] bitline_n_logical;
logic [31:0] bitline_xor;

logic [64:0] compute_sel;
logic [3:0] read_sel;
logic [31:0] compute_op_mux;
logic [31:0] read_op_mux;
//logic [7:0] serial_gf_product;

//logic [7:0] parallel_gf_product;
logic       factor_sel;

logic gf_mult_update;
logic gf_mult_set_msb;

logic [31:0] bitline_mask;
logic [4:0] shift_amount;

logic [7:0] sram_addr_a;
logic [7:0] sram_addr_b;
logic [31:0] sram_data_a;
logic [31:0] sram_data_b;
logic       sram_wren_a;
logic       sram_wren_b;

logic [32-1:0]  current_instructions [0:2];
logic [PC_WIDTH-1:0]    program_counter;


logic           avalon_mm_waitrequest;
logic  [31:0]   avalon_mm_readdata;
logic           avalon_mm_readdatavalid;

logic [31:0]    avalon_mm_writedata;
logic [8:0]     avalon_mm_address;
logic           avalon_mm_write;
logic           avalon_mm_read;

logic [31:0]    adder_data;
logic           update_carry;
logic [31:0]    carry;
logic           load_carry;


`ifdef MODEL_TECH

ram_model #(
    .ADDR_WIDTH (8),
    .DATA_WIDTH (32),
    .VERBOSE    (1)
) ram_model_inst (
    .address_a  (sram_addr_a),
    .address_b  (sram_addr_b),
    .clock      (sys_clk_in),
    .data_a     (sram_data_a),
    .data_b     (sram_data_b),
    .wren_a     (sram_wren_a),
    .wren_b     (sram_wren_b),
    .q_a        (bitline_a),
    .q_b        (bitline_b)
);

`else

SRAM_emu    SRAM_emu_inst (
    .address_a  (sram_addr_a),
    .address_b  (sram_addr_b),
    .clock      (sys_clk_in),
    .data_a     (sram_data_a),
    .data_b     (sram_data_b),
    .wren_a     (sram_wren_a),
    .wren_b     (sram_wren_b),
    .q_a        (bitline_a),
    .q_b        (bitline_b)
);

`endif


rw_control #(
    .PC_WIDTH           (PC_WIDTH)
) rw_control_inst (
    .compute_data_in    (read_op_mux),
    .sys_clk_in         (sys_clk_in),
    .sys_reset_in       (sys_reset_in),

    //SRAM signals
    .sram_addr_a_out    (sram_addr_a),
    .sram_addr_b_out    (sram_addr_b),

    .sram_data_a_out    (sram_data_a),
    .sram_data_b_out    (sram_data_b),

    .sram_wren_a_out    (sram_wren_a),
    .sram_wren_b_out    (sram_wren_b),
    
    //Datapath signals
    .compute_sel_out        (compute_sel),
    .read_sel_out           (read_sel),
    .bitline_mask_out       (bitline_mask),
    .shift_amount_out       (shift_amount),
    .factor_sel_out         (factor_sel),
    .gf_mult_update_out     (gf_mult_update),
    .gf_mult_set_msb_out    (gf_mult_set_msb),
    .update_carry_out       (update_carry),
    .carry_out              (carry),
    .load_carry_out         (load_carry),
    
    //Instruction memory signals
    //.pc_out             (program_counter),
    //.instructions_in    (current_instructions)
    .avalon_mm_waitrequest_out      (IMC_mm_waitrequest_out),
    .avalon_mm_readdata_out         (IMC_mm_readdata_out),
    .avalon_mm_readdatavalid_out    (IMC_mm_readdatavalid_out),

    .avalon_mm_writedata_in         (IMC_mm_writedata_in),
    .avalon_mm_address_in           (IMC_mm_address_in),
    .avalon_mm_write_in             (IMC_mm_write_in),
    .avalon_mm_read_in              (IMC_mm_read_in),
    
    .readback_data_in               (bitline_a)
);



//Not implemented for NIOS Version
/* instruction_rom #(
    .INSTRUCTION_WIDTH  (32),
    .PC_WIDTH           (PC_WIDTH)
) instruction_rom_inst (
    .pc_in              (program_counter),
    .instructions_out   (current_instructions)   //Need to look two instuctions ahead. 1 for next fetch and two with extension field.
); */


//Create bitline not portion of diff SRAM pair
assign bitline_a_n  = ~bitline_a;
assign bitline_b_n  = ~bitline_b;

//ANDing bitlines together produces the NOR of non inverted values in SRAM
//Doing this instead of simply ORing non inverted values in order to try
//to copy SRAM logical representation even if this is irrelevant for FPGA implementation
//----------------------------------------
//| A | B | ~A | ~B | ~A & ~B | ~(A | B) |
//----------------------------------------
//| 0 | 0 |  1 |  1 |    1    |     1    |
//| 0 | 1 |  1 |  0 |    0    |     0    |
//| 1 | 0 |  0 |  1 |    0    |     0    |
//| 1 | 1 |  0 |  0 |    0    |     0    |

assign bitline_n_logical    = bitline_a_n & bitline_b_n;

//Simultaneous accesses to two word lines in SRAM will produce AND on Bitlines
assign bitline_logical    = bitline_a & bitline_b;


//NORing two bitline products produces XOR of A and B
// C = ~(A | B)
// D =  A & B
//--------------------------------------
//| A | B | ~A | ~B | C | D | ~(C | D) |
//--------------------------------------
//| 0 | 0 |  1 |  1 | 1 | 0 |     0    |
//| 0 | 1 |  1 |  0 | 0 | 0 |     1    |
//| 1 | 0 |  0 |  1 | 0 | 0 |     1    |
//| 1 | 1 |  0 |  0 | 0 | 1 |     0    |
assign bitline_xor  = ~(bitline_logical | bitline_n_logical);


generate
genvar i;
    for (i = 0; i < 32; i++) begin : bitwise_op
    always_comb begin
        case (compute_sel[(i*2)+1:(i*2)])
            2'h0    : compute_op_mux[i] = ~bitline_n_logical[i];    //Logical OR (Inverted NOR)
            2'h1    : compute_op_mux[i] = bitline_logical[i];       //Logical AND
            2'h2    : compute_op_mux[i] = bitline_xor[i];           //Logical XOR
            2'h3    : compute_op_mux[i] = bitline_a[i];             //Pass Through
            //default : compute_op_mux[i] = 1'b0;                     //Shouldn't happen
        endcase
    end
    end

endgenerate

// synthesis translate_off
// assert (compute_sel !== 2'h3)
    // else $warning("Compute Operation Mux set to Invalid State (%h), Check Instruction",compute_sel);
// synthesis translate_on


always_comb begin
    case (read_sel)
        4'h0    : read_op_mux = compute_op_mux;  //Move Instruction
        4'h1    : read_op_mux = {'0,^compute_op_mux};  //Bitwise reduction XOR, convert to scalar and then zero pad
        4'h2    : read_op_mux = {'0,&(compute_op_mux | ~bitline_mask)};  //Bitwise reduction AND
        4'h3    : read_op_mux = compute_op_mux << shift_amount;  //Logical Shift Left
        4'h4    : read_op_mux = compute_op_mux >> shift_amount;  //Logical Shift Right
        //4'h5    : read_op_mux = parallel_gf_product;
        //4'h6    : read_op_mux = serial_gf_product;
        4'h7    : read_op_mux = ~compute_op_mux;  //Logical Inverse
        4'h8    : read_op_mux = adder_data;  //Technically doesn't belong on the "read" mux but this is a good place
        default : read_op_mux = '0;
    endcase
end

/* parallel_gf_mult    parallel_gf_mult_inst (
    .byte_in        (compute_op_mux[7:0]),
    .product_out    (parallel_gf_product),
    .factor_sel_in  (factor_sel)
);

serial_gf_mult  serial_gf_mult_inst (
    //System Signals
    .sys_clk_in     (sys_clk_in),
    .sys_reset_in   (sys_reset_in),
    //Datapath Control
    .bitline_in     (compute_op_mux[7:0]),
    .product_out    (serial_gf_product),
    .factor_sel_in  (),
    .update_in      (gf_mult_update),
    .set_msb_in     (gf_mult_set_msb)
);
 */
 
 
 serial_add  serial_add_inst (
    //System Signals
    .sys_clk_in         (sys_clk_in),
    .sys_reset_in       (sys_reset_in),
    //Datapath Control
    .carry_in           (carry),
    .load_carry_in      (load_carry),
    .update_carry_in    (update_carry),
    //Data Control
    .and_in             (bitline_logical),
    .xor_in             (bitline_xor),
    .sum_out            (adder_data)
);

endmodule

