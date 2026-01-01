// AES ShiftRows transform
module aes_shiftrows(
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);
    // Row-wise shifts (assuming column-major state: [0,4,8,12] is row0)
    assign state_out[8*0+7  : 8*0]  = state_in[8*0+7  : 8*0];
    assign state_out[8*4+7  : 8*4]  = state_in[8*4+7  : 8*4];
    assign state_out[8*8+7  : 8*8]  = state_in[8*8+7  : 8*8];
    assign state_out[8*12+7 : 8*12] = state_in[8*12+7 : 8*12];

    assign state_out[8*1+7  : 8*1]  = state_in[8*5+7  : 8*5];
    assign state_out[8*5+7  : 8*5]  = state_in[8*9+7  : 8*9];
    assign state_out[8*9+7  : 8*9]  = state_in[8*13+7 : 8*13];
    assign state_out[8*13+7 : 8*13] = state_in[8*1+7  : 8*1];

    assign state_out[8*2+7  : 8*2]  = state_in[8*10+7 : 8*10];
    assign state_out[8*6+7  : 8*6]  = state_in[8*14+7 : 8*14];
    assign state_out[8*10+7 : 8*10] = state_in[8*2+7  : 8*2];
    assign state_out[8*14+7 : 8*14] = state_in[8*6+7  : 8*6];

    assign state_out[8*3+7  : 8*3]  = state_in[8*15+7 : 8*15];
    assign state_out[8*7+7  : 8*7]  = state_in[8*3+7  : 8*3];
    assign state_out[8*11+7 : 8*11] = state_in[8*7+7  : 8*7];
    assign state_out[8*15+7 : 8*15] = state_in[8*11+7 : 8*11];
endmodule
