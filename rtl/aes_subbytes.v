// Apply S-Box to each byte of 128-bit state
module aes_subbytes(
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_sboxes
            aes_sbox u_sbox(
                .a(state_in[8*i+7 : 8*i]),
                .y(state_out[8*i+7 : 8*i])
            );
        end
    endgenerate
endmodule
