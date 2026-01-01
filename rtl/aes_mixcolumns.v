// AES MixColumns transform (operates on 128-bit state)
module aes_mixcolumns(
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    function automatic [7:0] xtime;
        input [7:0] x;
        begin
            xtime = {x[6:0],1'b0} ^ (8'h1b & {8{x[7]}});
        end
    endfunction

    function automatic [31:0] mix_col;
        input [31:0] c; // bytes [7:0]=s0, [15:8]=s1, [23:16]=s2, [31:24]=s3 (column)
        reg [7:0] s0,s1,s2,s3;
        reg [7:0] t, u, v;
        begin
            s0 = c[7:0]; s1 = c[15:8]; s2 = c[23:16]; s3 = c[31:24];
            t = s0 ^ s1 ^ s2 ^ s3;
            u = s0; v = s0 ^ s1; v = xtime(v); s0 = s0 ^ v ^ t;
            v = s1 ^ s2; v = xtime(v); s1 = s1 ^ v ^ t;
            v = s2 ^ s3; v = xtime(v); s2 = s2 ^ v ^ t;
            v = s3 ^ u;  v = xtime(v); s3 = s3 ^ v ^ t;
            mix_col = {s3,s2,s1,s0};
        end
    endfunction

    // State as 4 columns (column-major byte order):
    // Column 0 -> bytes [0,1,2,3]; Column 1 -> [4,5,6,7]; etc.
    wire [31:0] c0 = {state_in[8*3+7 :8*3],  state_in[8*2+7 :8*2],
                      state_in[8*1+7 :8*1],  state_in[8*0+7 :8*0]};
    wire [31:0] c1 = {state_in[8*7+7 :8*7],  state_in[8*6+7 :8*6],
                      state_in[8*5+7 :8*5],  state_in[8*4+7 :8*4]};
    wire [31:0] c2 = {state_in[8*11+7:8*11], state_in[8*10+7:8*10],
                      state_in[8*9+7 :8*9],  state_in[8*8+7 :8*8]};
    wire [31:0] c3 = {state_in[8*15+7:8*15], state_in[8*14+7:8*14],
                      state_in[8*13+7:8*13], state_in[8*12+7:8*12]};

    wire [31:0] mc0 = mix_col(c0);
    wire [31:0] mc1 = mix_col(c1);
    wire [31:0] mc2 = mix_col(c2);
    wire [31:0] mc3 = mix_col(c3);

    // Write back columns to their original positions
    assign state_out[8*0+7  :8*0]  = mc0[7:0];
    assign state_out[8*1+7  :8*1]  = mc0[15:8];
    assign state_out[8*2+7  :8*2]  = mc0[23:16];
    assign state_out[8*3+7  :8*3]  = mc0[31:24];

    assign state_out[8*4+7  :8*4]  = mc1[7:0];
    assign state_out[8*5+7  :8*5]  = mc1[15:8];
    assign state_out[8*6+7  :8*6]  = mc1[23:16];
    assign state_out[8*7+7  :8*7]  = mc1[31:24];

    assign state_out[8*8+7  :8*8]  = mc2[7:0];
    assign state_out[8*9+7  :8*9]  = mc2[15:8];
    assign state_out[8*10+7 :8*10] = mc2[23:16];
    assign state_out[8*11+7 :8*11] = mc2[31:24];

    assign state_out[8*12+7 :8*12] = mc3[7:0];
    assign state_out[8*13+7 :8*13] = mc3[15:8];
    assign state_out[8*14+7 :8*14] = mc3[23:16];
    assign state_out[8*15+7 :8*15] = mc3[31:24];
endmodule
