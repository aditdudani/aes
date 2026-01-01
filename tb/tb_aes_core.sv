`timescale 1ns/1ps
module tb_aes_core;
    reg clk=0, rst_n=0;
    always #5 clk = ~clk; // 100 MHz

    // DUT
    reg start;
    reg [127:0] key;
    reg [127:0] block_in;
    wire busy, valid;
    wire [127:0] block_out;

    aes_core dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .key(key), .block_in(block_in),
        .busy(busy), .valid(valid), .block_out(block_out)
    );

    task automatic reset_dut;
        begin
            rst_n = 0; start = 0; key = '0; block_in = '0;
            repeat (4) @(posedge clk);
            rst_n = 1; @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb/sim/tb_aes_core.vcd");
        $dumpvars(0, tb_aes_core);
        reset_dut();
        // NIST SP 800-38A F.1.1 AES-128 ECB
        key      = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        block_in = 128'h6bc1bee22e409f96e93d7e117393172a;
        @(posedge clk);
        start = 1; @(posedge clk); start = 0;
        wait (valid);
        if (block_out === 128'h3ad77bb40d7a3660a89ecaf32466ef97) begin
            $display("AES-128 ECB vector PASS");
        end else begin
            $display("AES-128 ECB vector FAIL: %h", block_out);
        end
        #20 $finish;
    end
endmodule
