`timescale 1ns/1ps
module tb_aes_mixcolumns;
  reg  [127:0] in;
  wire [127:0] out;
  aes_mixcolumns dut(.state_in(in), .state_out(out));

  // Reference MixColumns to compute expected output matching module's byte mapping
  function automatic [7:0] xtime;
    input [7:0] x;
    begin xtime = {x[6:0],1'b0} ^ (8'h1b & {8{x[7]}}); end
  endfunction
  function automatic [31:0] mix_col;
    input [31:0] c;
    reg [7:0] s0,s1,s2,s3; reg [7:0] t,u,v;
    begin
      s0=c[7:0]; s1=c[15:8]; s2=c[23:16]; s3=c[31:24];
      t = s0 ^ s1 ^ s2 ^ s3;
      u = s0; v = s0 ^ s1; v = xtime(v); s0 = s0 ^ v ^ t;
      v = s1 ^ s2; v = xtime(v); s1 = s1 ^ v ^ t;
      v = s2 ^ s3; v = xtime(v); s2 = s2 ^ v ^ t;
      v = s3 ^ u;  v = xtime(v); s3 = s3 ^ v ^ t;
      mix_col = {s3,s2,s1,s0};
    end
  endfunction

  function automatic [127:0] mc_ref;
    input [127:0] x;
    reg [31:0] c0,c1,c2,c3, mc0,mc1,mc2,mc3;
    reg [127:0] y;
    begin
      c0 = {x[8*3+7:8*3],  x[8*2+7:8*2],  x[8*1+7:8*1],  x[8*0+7:8*0]};
      c1 = {x[8*7+7:8*7],  x[8*6+7:8*6],  x[8*5+7:8*5],  x[8*4+7:8*4]};
      c2 = {x[8*11+7:8*11],x[8*10+7:8*10],x[8*9+7:8*9],  x[8*8+7:8*8]};
      c3 = {x[8*15+7:8*15],x[8*14+7:8*14],x[8*13+7:8*13],x[8*12+7:8*12]};
      mc0 = mix_col(c0); mc1 = mix_col(c1); mc2 = mix_col(c2); mc3 = mix_col(c3);
      y[8*0+7:8*0]   = mc0[7:0];   y[8*1+7:8*1]   = mc0[15:8];
      y[8*2+7:8*2]   = mc0[23:16]; y[8*3+7:8*3]   = mc0[31:24];
      y[8*4+7:8*4]   = mc1[7:0];   y[8*5+7:8*5]   = mc1[15:8];
      y[8*6+7:8*6]   = mc1[23:16]; y[8*7+7:8*7]   = mc1[31:24];
      y[8*8+7:8*8]   = mc2[7:0];   y[8*9+7:8*9]   = mc2[15:8];
      y[8*10+7:8*10] = mc2[23:16]; y[8*11+7:8*11] = mc2[31:24];
      y[8*12+7:8*12] = mc3[7:0];   y[8*13+7:8*13] = mc3[15:8];
      y[8*14+7:8*14] = mc3[23:16]; y[8*15+7:8*15] = mc3[31:24];
      mc_ref = y;
    end
  endfunction

  function automatic [127:0] pack;
    input [7:0] b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15;
    begin pack = {b15,b14,b13,b12,b11,b10,b9,b8,b7,b6,b5,b4,b3,b2,b1,b0}; end
  endfunction

  initial begin
    $dumpfile("tb/sim/tb_aes_mixcolumns.vcd");
    $dumpvars(0, tb_aes_mixcolumns);
    // Col0 pattern only
    in = pack(8'hdb,8'h13,8'h53,8'h45,
              8'h00,8'h00,8'h00,8'h00,
              8'h00,8'h00,8'h00,8'h00,
              8'h00,8'h00,8'h00,8'h00);
    #1;
    if (out !== mc_ref(in)) $fatal(1, "MixColumns col0 mismatch: got=%h exp=%h", out, mc_ref(in));

    // Col1 pattern only
    in = pack(8'h00,8'h00,8'h00,8'h00,
              8'hf2,8'h0a,8'h22,8'h5c,
              8'h00,8'h00,8'h00,8'h00,
              8'h00,8'h00,8'h00,8'h00);
    #1;
    if (out !== mc_ref(in)) $fatal(1, "MixColumns col1 mismatch: got=%h exp=%h", out, mc_ref(in));

    $display("MixColumns PASS");
    $finish;
  end
endmodule
