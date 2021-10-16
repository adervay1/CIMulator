//Performs multiply by a constant 2 or 3 in GF(2^8)
module serial_gf_mult (
    //System Signals
    input           sys_clk_in,
    input           sys_reset_in,
    //Datapath Control
    input [7:0]     bitline_in,
    output [7:0]    product_out,
    input           factor_sel_in,
    input           update_in,
    input           set_msb_in
);


localparam logic [7:0] GF_POLY = 8'h1B;
localparam DATA_WIDTH = 8;

logic [DATA_WIDTH-1:0]  msb_reg;
logic [DATA_WIDTH-1:0]  sum;
logic [DATA_WIDTH-1:0]  product;
logic                   set_msb_d;
logic [2:0]             const_counter;



always_ff @ (posedge sys_clk_in or posedge sys_reset_in) begin
    if (sys_reset_in) begin
        msb_reg     <= '0;
        set_msb_d   <= 1'b0;
    end else begin
        set_msb_d   <= set_msb_in;
        if (set_msb_in) begin
            msb_reg     <= bitline_in;
        end
    end
end


/* always_ff @ (posedge sys_clk_in or posedge sys_reset_in) begin
    if (sys_reset_in) begin
        product <= '0;
    end else begin
        if (set_msb_d) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                product[i] <= (msb_reg[i]) ? 1'b1 : 1'b0;
            end
        end else begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                product[i] <= (msb_reg[i]) ? bitline_in[i] ^ GF_POLY[const_counter] : bitline_in[i];
            end
        end
    end
end */

always_comb begin
    if (set_msb_in) begin
        product     = bitline_in;                   // This is a simplification of the input byte shifted << 1 and XOR'd with 0x1B.
    end else begin                                  // Since a logic shift left shifts in zero, it means the lsb of mult by 2 is equal to
    for (int i = 0; i < DATA_WIDTH; i++) begin  // (MSB) ? 0 ^ 0x1B[0] : 0; which equals (MSB) ? 0 ^ 1 : 0; , the identity of MSB
        product[i] = (msb_reg[i]) ? (bitline_in[i] ^  GF_POLY[const_counter]): bitline_in[i];
    end
    end
end

always_ff @ (posedge sys_clk_in or posedge sys_reset_in) begin
    if (sys_reset_in) begin
        const_counter   <= '0;
    end else begin
        if (update_in) begin
            const_counter   <= const_counter + 1'b1;
        end else if (set_msb_in) begin
            const_counter   <=  3'b001;
        end
    end
end

assign product_out  = product;

endmodule