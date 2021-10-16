//Multiply input byte by a factor of 2 or 3 in GF(2^8)

module parallel_gf_mult (
    input   [7:0]   byte_in,
    output  [7:0]   product_out,
    input           factor_sel_in
);

logic [8:0] byte_ovf;
logic [7:0] fac_stage;
logic [7:0] product;


always_comb begin
    byte_ovf    = byte_in << 1;
    fac_stage   = (byte_ovf[8]) ? (byte_ovf[7:0] ^ 8'h1B) : byte_ovf[7:0];
    product     = (factor_sel_in) ? (fac_stage ^ byte_in) : fac_stage;
end

assign product_out  = product;

endmodule