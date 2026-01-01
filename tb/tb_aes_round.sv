`timescale 1ns/1ps
module tb_aes_round;
  reg clk=0; always #5 clk=~clk;
  reg en, skip;
  reg [127:0] st_in, rk;
  wire [127:0] st_out;
  aes_round dut(
    .clk(clk), .en(en), .skip_mixcols(skip),
    .state_in(st_in), .round_key(rk), .state_out(st_out)
  );

  // Use FIPS-197 Appendix B example, but translate to internal byte-order.
  // Internal submodules treat state in LSB-first byte order; define a byte-swap helper.
  function automatic [127:0] bswap128;
    input [127:0] x;
    integer i;
    begin
      for (i = 0; i < 16; i = i + 1)
        bswap128[8*i +: 8] = x[127 - 8*i -: 8];
    end
  endfunction
  initial begin
    en=0; skip=0; st_in=0; rk=0; @(posedge clk);
    // Example values in internal order (apply bswap):
    // initial ARK state
    st_in = bswap128(128'h00112233445566778899aabbccddeeff
                   ^ 128'h000102030405060708090a0b0c0d0e0f);
    rk    = bswap128(128'hd6aa74fdd2af72fadaa678f1d6ab76fe); // round 1 key
    $display("[TB_ROUND] st_in=%h rk=%h", st_in, rk);
    // Assert en long enough to avoid scheduling edge cases
    @(posedge clk); en=1; @(posedge clk); @(posedge clk); en=0; // one round captured on first posedge of en
    @(posedge clk);
    $display("[TB_ROUND] st_out=%h (ext)=%h", st_out, bswap128(st_out));
    if (bswap128(st_out) !== 128'h89d810e8855ace682d1843d8cb128fe4)
      $fatal(1, "aes_round mismatch: got=%h exp=%h", bswap128(st_out), 128'h89d810e8855ace682d1843d8cb128fe4);
    $display("aes_round PASS (FIPS Appendix B round1)");
    $finish;
  end
endmodule
