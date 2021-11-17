module circular_shift (
    input   [31:0]   byte_in,
    output  [31:0]   cshift_out,
    input   [4:0]    shift_amt_in
);


logic [31:0] cshift;


always_comb begin
    case(shift_amt_in)
        5'h01 : begin
                    cshift[31:4] = byte_in[31:4];
                    cshift[3] = byte_in[0];
                    cshift[2] = byte_in[3];
                    cshift[1] = byte_in[2];
                    cshift[0] = byte_in[1];
                end
        5'h02 : begin
                    cshift[31:4] = byte_in[31:4];
                    cshift[3] = byte_in[1];
                    cshift[2] = byte_in[0];
                    cshift[1] = byte_in[3];
                    cshift[0] = byte_in[2];
                end
        5'h03 : begin
                    cshift[31:4] = byte_in[31:4];
                    cshift[3] = byte_in[2];
                    cshift[2] = byte_in[1];
                    cshift[1] = byte_in[0];
                    cshift[0] = byte_in[3];
        
                end
        default : cshift  = byte_in;
    endcase
end

assign cshift_out  = cshift;

endmodule