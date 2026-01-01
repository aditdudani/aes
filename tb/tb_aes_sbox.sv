`timescale 1ns/1ps
module tb_aes_sbox;
  reg  [7:0] a;
  wire [7:0] y;
  aes_sbox dut(.a(a), .y(y));
  task automatic check;
    input [7:0] in;
    input [7:0] exp;
    begin
      a = in; #1;
      if (y !== exp) begin
        $display("SBOX FAIL: a=%02x y=%02x exp=%02x", in, y, exp);
        $finish;
      end else begin
        $display("SBOX PASS: a=%02x -> %02x", in, y);
      end
    end
  endtask
  initial begin
    $dumpfile("tb/sim/tb_aes_sbox.vcd");
    $dumpvars(0, tb_aes_sbox);
    check(8'h00, 8'h63);
    check(8'h53, 8'hed);
    check(8'hff, 8'h16);
    $display("SBOX tests PASS");
    $finish;
  end
endmodule
