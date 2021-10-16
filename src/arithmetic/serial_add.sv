module serial_add (
    //System Signals
    input           sys_clk_in,
    input           sys_reset_in,
    //Datapath Control
    input [31:0]     carry_in,
    input           load_carry_in,
    input           update_carry_in,
    //Data Control
    input [31:0]     and_in,
    input [31:0]     xor_in,
    output [31:0]    sum_out
);

logic [31:0] carry_reg,  next_carry_reg;
logic [31:0] sum;


always_ff @ (posedge sys_clk_in or posedge sys_reset_in) begin
    if (sys_reset_in) begin
        carry_reg   <= '0;
    end else begin
        carry_reg   <= next_carry_reg;
    end
end

always_comb begin
    if (load_carry_in) begin
        next_carry_reg  = carry_in;
    end else if (update_carry_in) begin
        next_carry_reg  = (xor_in & carry_reg) |  and_in;
    end else begin
        next_carry_reg  = carry_reg;
    end
end

assign sum = xor_in ^ carry_reg;

assign sum_out = sum;


endmodule