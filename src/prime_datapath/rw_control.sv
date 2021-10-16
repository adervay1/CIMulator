//AFD: When refactoring the code and pulling out memory array into an external module, I realized I imposed a design restiction where the rw_control needs to see at least 
//     two instructions ahead to account for the PC+2 logic on extension fields. This was less obvious when the instructions and decode logice were all in one module since it was
//     easy to grab arbitrary instrction addresses. I think for the moment it is fine to always grab the current instruction and two more for next instruction / extension field but
//     this is a architectural restriction that will limit scaling. If more complicated instruction fetching is needede, this will likely need to be reworked.
//     For now this works fine just running a "batch" program without any instruction jump logic / HW.

module rw_control # (
    parameter PC_WIDTH = 8
) (
    input [31:0]            compute_data_in,
    input                   sys_clk_in,
    input                   sys_reset_in,
    
    output [7:0]            sram_addr_a_out,
    output [7:0]            sram_addr_b_out,
    
    output [31:0]           sram_data_a_out,
    output [31:0]           sram_data_b_out,
    
    output                  sram_wren_a_out,
    output                  sram_wren_b_out,
    
    output [63:0]           compute_sel_out,
    output [3:0]            read_sel_out,
    output [31:0]           bitline_mask_out,
    output [4:0]            shift_amount_out,
    output                  factor_sel_out,
    output                  gf_mult_update_out,
    output                  gf_mult_set_msb_out,
    
    output                  update_carry_out,
    output [31:0]           carry_out,
    output                  load_carry_out,
    
    //output [PC_WIDTH-1:0]   pc_out,
    //input [31:0]            instructions_in [0:2]

    //Avalon mm signals
    output          avalon_mm_waitrequest_out,
    output [31:0]   avalon_mm_readdata_out,
    output          avalon_mm_readdatavalid_out,

    input [31:0]    avalon_mm_writedata_in,
    input [8:0]     avalon_mm_address_in,
    input           avalon_mm_write_in,
    input           avalon_mm_read_in,
    
    input [31:0]     readback_data_in
);



//logic [PC_WIDTH-1:0]        program_counter, next_program_counter;

logic [7:0]     addr_a,  next_addr_a;
logic [7:0]     addr_b,  next_addr_b;

logic [31:0]     data_a,  next_data_a;
logic [31:0]     data_b,  next_data_b;

logic           wren_a,  next_wren_a;
logic           wren_b,  next_wren_b;

logic [63:0]    compute_sel, next_compute_sel;
logic [3:0]     read_sel, next_read_sel;
logic [31:0]     bitline_mask, next_bitline_mask;
logic [4:0]     shift_amount, next_shift_amount;
logic           factor_sel, next_factor_sel;
logic           gf_mult_set_msb, next_gf_mult_set_msb;
logic           gf_mult_update, next_gf_mult_update;
logic           update_carry, next_update_carry;
logic [31:0]    carry, next_carry;
logic           load_carry, next_load_carry;


logic           mm_waitrequest, next_mm_waitrequest;
logic [31:0]    mm_readdata, next_mm_readdata;
logic           mm_readdatavalid, next_mm_readdatavalid;

logic           sel_ff, next_sel_ff;

logic [31:0]    latched_command, next_latched_command;
logic [7:0]     latched_addr, next_latched_addr;

localparam      INSTRUCTION_WIDTH       = 32;
localparam      MAX_INSTRUCTION_DEPTH   = 256;
localparam      OP_FIELD_WIDTH      = 8;

localparam      OP_LOW_IDX          = INSTRUCTION_WIDTH - OP_FIELD_WIDTH; //Used for bitselecting LSB of OPCODE field

typedef enum logic [OP_FIELD_WIDTH-1:0] {  
                            IDLE        = 8'h1F,
                            LOAD        = 8'h00,
                            MOVE1       = 8'h01,
                            //COMP1       = 8'h02,
                            
                            ORC1        = 8'h03,
                            ANDC1       = 8'h04,
                            XORC1       = 8'h05,
                            
                            XORR1       = 8'h06,
                            //ANDR1       = 8'h07,
                            LSHFT1      = 8'h08,
                            RSHFT1      = 8'h09,
                            //P_GMUL2_1   = 8'h0A,
                            //P_GMUL3_1   = 8'h0B,
                            
                            //S_GMULINIT1 = 8'h0C,
                            //S_GMUL2_1   = 8'h0D,
                            
                            P_INV_1     = 8'h0E,
                            
                            ADDS1       = 8'h0F,
                            SCIN        = 8'h10,
                            
                            


                            EXT_READ_1  = 8'h80,
                            EXT_READ_2  = 8'h81,
                            
                            ADDS2       = 8'hEF,
                            //ADDS3       = 8'hEF,

                            P_INV_2   = 8'hF0,

                            //S_GMUL2_2   = 8'hF1,
                            //S_GMULINIT2 = 8'hF2,

                            //P_GMUL3_2   = 8'hF3,
                            //P_GMUL2_2   = 8'hF4,

                            RSHFT2      = 8'hF5,
                            LSHFT2      = 8'hF6,
                            //ANDR2       = 8'hF7,
                            XORR2       = 8'hF8,
                            
                            XORC2       = 8'hF9,
                            
                            ANDC2       = 8'hFA,
                            
                            ORC2        = 8'hFB,
                            
                            //COMP2       = 8'hFC,
                            //COMP3       = 8'hFD,
                            
                            MOVE2       = 8'hFE,
                            DONE        = 8'hFF
} RW_STATES;

RW_STATES state;
RW_STATES next_state;


always_ff @ (posedge sys_clk_in or posedge sys_reset_in) begin
    if (sys_reset_in) begin
        state               <= IDLE;
        //program_counter     <= '0;
        addr_a              <= '0;
        addr_b              <= '0;
        data_a              <= '0;
        data_b              <= '0;
        wren_a              <= '0;
        wren_b              <= '0;
        compute_sel         <= '1;
        read_sel            <= 2'h0;
        bitline_mask        <= 8'hFF;
        shift_amount        <= 3'h0;
        factor_sel          <= 1'b0;
        sel_ff              <= 1'b1;
        gf_mult_set_msb     <= 1'b0;
        gf_mult_update      <= 1'b0;
        update_carry        <= 1'b0;
        carry               <= '0;
        load_carry          <= 1'b0;
        
        mm_waitrequest      <= 1'b1;
        mm_readdata         <= '0;
        mm_readdatavalid    <= 1'b0;
        latched_command     <= '0;
        latched_addr        <= '0;
    end else begin
        state               <= next_state;
        //program_counter     <= next_program_counter;
        addr_a              <= next_addr_a;
        addr_b              <= next_addr_b;
        data_a              <= next_data_a;
        data_b              <= next_data_b;
        wren_a              <= next_wren_a;
        wren_b              <= next_wren_b;
        compute_sel         <= next_compute_sel;
        read_sel            <= next_read_sel;
        bitline_mask        <= next_bitline_mask;
        shift_amount        <= next_shift_amount;
        factor_sel          <= next_factor_sel;
        sel_ff              <= next_sel_ff;
        gf_mult_set_msb     <= next_gf_mult_set_msb;
        gf_mult_update      <= next_gf_mult_update;
        update_carry        <= next_update_carry;
        carry               <= next_carry;
        load_carry          <= next_load_carry;
        
        mm_waitrequest      <= next_mm_waitrequest;
        mm_readdata         <= next_mm_readdata;
        mm_readdatavalid    <= next_mm_readdatavalid;
        
        latched_command     <= next_latched_command;
        latched_addr        <= next_latched_addr;
    end
end


always_comb begin
    next_state              = state;
    //next_program_counter    = program_counter;
    next_addr_a             = addr_a;
    next_addr_b             = addr_b;
    next_data_a             = data_a;
    next_data_b             = data_b;
    next_wren_a             = 1'b0;
    next_wren_b             = 1'b0;
    next_compute_sel        = compute_sel;
    next_read_sel           = read_sel;
    next_bitline_mask       = bitline_mask;
    next_shift_amount       = shift_amount;
    next_factor_sel         = factor_sel;
    next_sel_ff             = sel_ff;
    next_gf_mult_set_msb    = 1'b0;
    next_gf_mult_update     = 1'b0;
    next_update_carry       = 1'b0;
    next_carry              = carry;
    next_load_carry         = 1'b0;
    
    next_mm_waitrequest     = mm_waitrequest;
    next_mm_readdata        = mm_readdata;
    next_mm_readdatavalid   = 1'b0;
    next_latched_command    = latched_command;
    next_latched_addr       = latched_addr;
    
    case(state)
        IDLE :
            begin
                next_mm_waitrequest = 1'b0;
                if (avalon_mm_write_in) begin
                    if (avalon_mm_address_in[8] == 1'b1) begin
                        next_state = LOAD;
                        next_latched_addr       = avalon_mm_address_in[7:0];
                        next_latched_command    = avalon_mm_writedata_in;
                    end else begin
                        next_state = RW_STATES'(avalon_mm_writedata_in[INSTRUCTION_WIDTH-1:OP_LOW_IDX]);
                        next_latched_command = avalon_mm_writedata_in;
                    end
                end else if (avalon_mm_read_in) begin
                    next_addr_a             = avalon_mm_address_in[7:0];
                    next_latched_addr       = avalon_mm_address_in[7:0];
                    next_mm_readdatavalid   = 1'b0;
                    next_mm_readdata        = '0;
                    next_mm_waitrequest     = 1'b1;
                    next_state              = EXT_READ_1;
                end else begin
                    next_state = IDLE;
                end
            end



        EXT_READ_1 :
            begin
                next_addr_a             = latched_addr;
                next_mm_readdatavalid   = 1'b0;
                next_mm_readdata        = '0;
                next_mm_waitrequest     = 1'b1;
                next_state = EXT_READ_2;
            end
            
        EXT_READ_2 :
            begin
                next_addr_a             = latched_addr;
                next_mm_readdatavalid   = 1'b1;
                next_mm_waitrequest     = 1'b0;
                next_mm_readdata        = readback_data_in;
                
                next_state = IDLE;
            end




        //Load Instruction
        LOAD :
            begin
                next_addr_b = latched_addr;
                next_data_b = latched_command;
                next_wren_b = 1'b1;
                
                next_sel_ff         = 1'b1;
                
                next_read_sel       = 4'h0;
                next_compute_sel    = '1;


                next_state = IDLE;
            end


 
        //Move Instruction
        MOVE1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = '0;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel       = 4'h0;
                next_compute_sel    = '1;
                
                next_state = MOVE2;
            end
        MOVE2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        XORR1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = '0;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel   = 4'h1;
                next_compute_sel    = '1;
                
                next_state = XORR2;
            end
        XORR2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end


/* 
ANDR currently removed for 32 bit version due to expanded mask field
        ANDR1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = '0;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel       = 4'h2;
                next_compute_sel    = '1;
                next_bitline_mask   = latched_command[7:0];
                
                next_state = ANDR2;
            end
        ANDR2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end
 */


        LSHFT1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = '0;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel       = 4'h3;
                next_compute_sel    = '1;
                next_shift_amount   = latched_command[4:0];
                
                next_state = LSHFT2;
            end
        LSHFT2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        RSHFT1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = '0;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel       = 4'h4;
                next_compute_sel    = '1;
                next_shift_amount   = latched_command[4:0];
                
                next_state = RSHFT2;
            end
        RSHFT2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        P_INV_1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = '0;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel       = 4'h7;
                next_compute_sel    = '1;
                
                next_state = P_INV_2;
            end
        P_INV_2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end


        ORC1 :
            begin
                next_addr_a         = latched_command[23:16];
                next_addr_b         = latched_command[15:8];
                
                next_compute_sel    = '0;
                next_read_sel       = 4'h0;
                next_sel_ff         = 1'b0;
                
                next_state  = ORC2;
            end
        ORC2 :
            begin
                next_addr_b = latched_command[7:0];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        ANDC1 :
            begin
                next_addr_a         = latched_command[23:16];
                next_addr_b         = latched_command[15:8];
                
                next_compute_sel    = 64'h5555555555555555;
                next_read_sel       = 4'h0;
                next_sel_ff         = 1'b0;
                
                next_state  = ANDC2;
            end
        ANDC2 :
            begin
                
                next_addr_b = latched_command[7:0];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        XORC1 :
            begin
                next_addr_a         = latched_command[23:16];
                next_addr_b         = latched_command[15:8];
                
                next_compute_sel    = 64'hAAAAAAAAAAAAAAAA;
                next_read_sel       = 4'h0;
                next_sel_ff         = 1'b0;
                
                next_state  = XORC2;
            end
        XORC2 :
            begin
                
                next_addr_b = latched_command[7:0];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end

//Leave out for now on 32-bit implementation
/*         P_GMUL2_1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = 8'h00;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel       = 4'h5;
                next_compute_sel    = '1;
                next_factor_sel     = 1'b0;
                
                next_state = P_GMUL2_2;
            end
        P_GMUL2_2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        P_GMUL3_1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = 8'h00;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel       = 4'h5;
                next_compute_sel    = '1;
                next_factor_sel     = 1'b1;
                
                next_state = P_GMUL2_2;
            end
        P_GMUL3_2 :
            begin
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        S_GMULINIT1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = 8'h00;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel           = 4'h6;
                next_compute_sel        = '1;
                //next_gf_mult_set_msb    = 1'b1;
                //next_shift_amount   = latched_command[2:0];
                
                next_state = S_GMULINIT2;
            end
        S_GMULINIT2 :
            begin
                next_gf_mult_set_msb    = 1'b1;
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end



        S_GMUL2_1 :
            begin
                next_addr_a = latched_command[23:16];
                next_data_b = 8'h00;
                
                next_sel_ff         = 1'b0;
                
                next_read_sel           = 4'h6;
                next_compute_sel        = '1;
                //next_gf_mult_set_msb    = 1'b1;
                //next_shift_amount   = latched_command[2:0];
                
                next_state = S_GMUL2_2;
            end
        S_GMUL2_2 :
            begin
                next_gf_mult_update     = 1'b1;
                next_addr_a = latched_command[23:16];
                next_addr_b = latched_command[15:8];
                next_wren_b = 1'b1;
                
                next_state = IDLE;
            end
 */



        // ADDS1 :
            // begin
                // next_addr_a         = latched_command[23:16];
                // next_addr_b         = latched_command[15:8];
                
                // next_compute_sel    = '1;
                // next_read_sel       = 4'h8;
                // next_sel_ff         = 1'b1;
                
                // next_state  = ADDS2;
            // end
        // ADDS2 :
            // begin
                // next_update_carry   = 1'b1;
                // next_state  = ADDS3;
            // end
        // ADDS3 :
            // begin
                // next_addr_b = latched_command[7:0];
                // next_data_b = compute_data_in;
                
                // next_wren_b = 1'b1;
                
                // next_state = IDLE;
            // end
        ADDS1 :
            begin
                next_addr_a         = latched_command[23:16];
                next_addr_b         = latched_command[15:8];
                
                next_compute_sel    = '1;
                next_read_sel       = 4'h8;
                next_sel_ff         = 1'b0;
                
                next_state  = ADDS2;
            end
        ADDS2 :
            begin
                next_addr_b = latched_command[7:0];
                
                next_wren_b = 1'b1;
                
                next_update_carry   = 1'b1;
                
                next_state = IDLE;
            end




        SCIN :
            begin
                next_load_carry         = 1'b1;
                next_carry              = {24'h00_0000,latched_command[23:16]}; //Pad with zeros for now. Need differenc SCIN mechanism to work with 32-bit

                next_state = IDLE;
            end



        DONE :
            begin
                next_addr_a = '0;
                next_addr_b = '0;
                next_data_a = '0;
                next_data_b = '0;
                
                next_state = DONE;
            end
    endcase
end


assign sram_addr_a_out  = addr_a;
assign sram_addr_b_out  = addr_b;
assign sram_data_a_out  = data_a;


assign sram_data_b_out  = (sel_ff) ? data_b : compute_data_in;


assign sram_wren_a_out      = wren_a;
assign sram_wren_b_out      = wren_b;
assign compute_sel_out      = compute_sel;
assign read_sel_out         = read_sel;
assign bitline_mask_out     = bitline_mask;
assign shift_amount_out     = shift_amount;
assign factor_sel_out       = factor_sel;
assign gf_mult_set_msb_out  = gf_mult_set_msb;
assign gf_mult_update_out   = gf_mult_update;
assign update_carry_out     = update_carry;
assign carry_out            = carry;
assign load_carry_out       = load_carry;



//assign pc_out           = program_counter;

assign avalon_mm_waitrequest_out    = mm_waitrequest;
assign avalon_mm_readdata_out       = mm_readdata;
assign avalon_mm_readdatavalid_out  = mm_readdatavalid;


endmodule

