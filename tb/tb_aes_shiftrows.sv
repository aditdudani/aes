`timescale 1ns/1ps
module tb_aes_shiftrows;
  reg  [127:0] in;
  wire [127:0] out;
  aes_shiftrows dut(.state_in(in), .state_out(out));
  // Pattern bytes = index value 0..15
  // Expected after ShiftRows (column-major):
  // row0: 0,4,8,12 (unchanged)
  // row1: 1,5,9,13 -> 5,9,13,1
  // row2: 2,6,10,14 -> 10,14,2,6
  // row3: 3,7,11,15 -> 15,3,7,11
  function automatic [127:0] pack;
    input [7:0] b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15;
    begin
      pack = {b15,b14,b13,b12,b11,b10,b9,b8,b7,b6,b5,b4,b3,b2,b1,b0};
    end
  endfunction
  initial begin
    $dumpfile("tb/sim/tb_aes_shiftrows.vcd");
    $dumpvars(0, tb_aes_shiftrows);
    in = pack(8'h00,8'h01,8'h02,8'h03,
          8'h04,8'h05,8'h06,8'h07,
          8'h08,8'h09,8'h0a,8'h0b,
          8'h0c,8'h0d,8'h0e,8'h0f);
    #1;
    if (out[8*0 +:8]  !== 8'h00) $fatal(1, "SR mismatch at 0");
    if (out[8*4 +:8]  !== 8'h04) $fatal(1, "SR mismatch at 4");
    if (out[8*8 +:8]  !== 8'h08) $fatal(1, "SR mismatch at 8");
    if (out[8*12+:8]  !== 8'h0c) $fatal(1, "SR mismatch at 12");
    if (out[8*1 +:8]  !== 8'h05) $fatal(1, "SR mismatch at 1");
    if (out[8*5 +:8]  !== 8'h09) $fatal(1, "SR mismatch at 5");
    if (out[8*9 +:8]  !== 8'h0d) $fatal(1, "SR mismatch at 9");
    if (out[8*13+:8]  !== 8'h01) $fatal(1, "SR mismatch at 13");
    if (out[8*2 +:8]  !== 8'h0a) $fatal(1, "SR mismatch at 2");
    if (out[8*6 +:8]  !== 8'h0e) $fatal(1, "SR mismatch at 6");
    if (out[8*10+:8]  !== 8'h02) $fatal(1, "SR mismatch at 10");
    if (out[8*14+:8]  !== 8'h06) $fatal(1, "SR mismatch at 14");
    if (out[8*3 +:8]  !== 8'h0f) $fatal(1, "SR mismatch at 3");
    if (out[8*7 +:8]  !== 8'h03) $fatal(1, "SR mismatch at 7");
    if (out[8*11+:8]  !== 8'h07) $fatal(1, "SR mismatch at 11");
    if (out[8*15+:8]  !== 8'h0b) $fatal(1, "SR mismatch at 15");
    $display("ShiftRows PASS");
    $finish;
  end
endmodule
