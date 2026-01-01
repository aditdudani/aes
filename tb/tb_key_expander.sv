`timescale 1ns/1ps
module tb_key_expander;
  reg clk=0, rst_n=0;
  always #5 clk = ~clk;
  reg load, next;
  reg  [127:0] key_in;
  wire [127:0] key_out;
  wire [3:0]   round;

  key_expander dut(
    .clk(clk), .rst_n(rst_n), .load(load), .next(next),
    .key_in(key_in), .key_out(key_out), .round(round)
  );

  task automatic rst;
    begin
      rst_n=0; load=0; next=0; key_in=0; repeat(2) @(posedge clk); rst_n=1; @(posedge clk);
    end
  endtask

  initial begin
    $dumpfile("tb/sim/tb_key_expander.vcd");
    $dumpvars(0, tb_key_expander);
    rst();
    key_in = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    load = 1; @(posedge clk); load = 0;
    // Round 1..4 spot-checks
    next = 1; @(posedge clk); next = 0; @(posedge clk);
    if (key_out !== 128'ha0fafe1788542cb123a339392a6c7605) $fatal(1, "RK1 mismatch: %h", key_out);
    next = 1; @(posedge clk); next = 0; @(posedge clk);
    if (key_out !== 128'hf2c295f27a96b9435935807a7359f67f) $fatal(1, "RK2 mismatch: %h", key_out);
    next = 1; @(posedge clk); next = 0; @(posedge clk);
    if (key_out !== 128'h3d80477d4716fe3e1e237e446d7a883b) $fatal(1, "RK3 mismatch: %h", key_out);
    next = 1; @(posedge clk); next = 0; @(posedge clk);
    if (key_out !== 128'hef44a541a8525b7fb671253bdb0bad00) $fatal(1, "RK4 mismatch: %h", key_out);
    $display("KeyExpander PASS (first 4 rounds)");
    $finish;
  end
endmodule
