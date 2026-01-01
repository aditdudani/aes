`timescale 1ns/1ps
module tb_aes_ctr_core;
    reg clk=0, rst_n=0; always #5 clk=~clk;
    // DUT
    reg start;
    reg [127:0] key, iv;
    reg in_valid, in_last;
    wire in_ready;
    reg [127:0] in_data; reg [15:0] in_keep;
    wire out_valid, out_last; reg out_ready; initial out_ready=1'b1;
    wire [127:0] out_data; wire [15:0] out_keep;
    wire [63:0] blocks; wire busy;

    aes_ctr_core dut (
        .clk(clk), .rst_n(rst_n), .start(start), .key(key), .iv(iv),
        .in_valid(in_valid), .in_ready(in_ready),
        .in_data(in_data), .in_keep(in_keep), .in_last(in_last),
        .out_valid(out_valid), .out_ready(out_ready),
        .out_data(out_data), .out_keep(out_keep), .out_last(out_last),
        .blocks_processed(blocks), .busy(busy)
    );

    // Reference AES core to compute keystreams
    reg ref_start; wire ref_busy, ref_valid; reg [127:0] ks0, ks1; wire [127:0] ref_out;
    reg [127:0] ref_block;
    aes_core ref_core (
        .clk(clk), .rst_n(rst_n), .start(ref_start),
        .key(key), .block_in(ref_block), .busy(ref_busy), .valid(ref_valid), .block_out(ref_out)
    );

    task automatic reset_dut;
        begin
            rst_n=0; start=0; in_valid=0; in_last=0; in_data='0;
            in_keep='0; key='0; iv='0; ref_start=0;
            repeat (5) @(posedge clk);
            rst_n=1; @(posedge clk);
        end
    endtask

    initial begin
        int failed;
        $dumpfile("tb/sim/tb_aes_ctr_core.vcd");
        $dumpvars(0, tb_aes_ctr_core);
        reset_dut();
        key = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        iv  = 128'hf0e0d0c0b0a090807060504030201000; // arbitrary IV
        // Precompute keystream 0 (ks0) using separate ref_block to avoid IV races
        ref_block = iv;
        @(posedge clk); ref_start=1; @(posedge clk); ref_start=0;
        begin : wait_ref0
            integer cyc; cyc = 0;
            while (!ref_valid && cyc < 3000) begin @(posedge clk); cyc = cyc + 1; end
            if (!ref_valid) begin $fatal(1, "Timeout waiting for ref_valid (ks0)"); end
        end
        ks0=ref_out; $display("[TB] ks0=%h", ks0);
        // Precompute keystream 1 (ks1) at IV+1
        ref_block = iv + 128'd1;
        @(posedge clk); ref_start=1; @(posedge clk); ref_start=0;
        begin : wait_ref1
            integer cyc; cyc = 0;
            while (!ref_valid && cyc < 3000) begin @(posedge clk); cyc = cyc + 1; end
            if (!ref_valid) begin $fatal(1, "Timeout waiting for ref_valid (ks1)"); end
        end
        ks1=ref_out; $display("[TB] ks1=%h", ks1);
        // Start DUT with original IV
        @(posedge clk); start=1; @(posedge clk); start=0;
        // Send two blocks
        // Block 0 full
        in_data  = 128'h00112233445566778899aabbccddeeff;
        in_keep  = 16'hffff; in_last = 1'b0; in_valid=1;
        begin : wait_in0
            integer cyc; cyc = 0;
            while (!in_ready && cyc < 200) begin @(posedge clk); cyc = cyc + 1; end
            if (!in_ready) begin $fatal(1, "Timeout waiting for in_ready (blk0)"); end
        end
        @(posedge clk); in_valid=0;
        begin : wait_out0
            integer cyc; cyc = 0;
            while (!out_valid && cyc < 10000) begin @(posedge clk); cyc = cyc + 1; end
            if (!out_valid) begin $fatal(1, "Timeout waiting for out_valid (blk0)"); end
        end
        $display("[TB] blk0 in=%h ks0=%h out=%h", in_data, ks0, out_data);
        if (out_data !== (in_data ^ ks0)) begin
            $error("CTR block0 mismatch exp=%h got=%h", (in_data ^ ks0), out_data);
            failed = 1;
        end else begin
            $display("[TB] Block0 OK");
        end
        // Block 1 partial (8 bytes)
        in_data  = 128'h1122334455667788_0000000000000000;
        in_keep  = 16'h00ff; in_last = 1'b1; in_valid=1;
        begin : wait_in1
            integer cyc; cyc = 0;
            while (!in_ready && cyc < 200) begin @(posedge clk); cyc = cyc + 1; end
            if (!in_ready) begin $fatal(1, "Timeout waiting for in_ready (blk1)"); end
        end
        @(posedge clk); in_valid=0;
        begin : wait_out1
            integer cyc; cyc = 0;
            while (!out_valid && cyc < 10000) begin @(posedge clk); cyc = cyc + 1; end
            if (!out_valid) begin $fatal(1, "Timeout waiting for out_valid (blk1)"); end
        end
        $display("[TB] blk1 in=%h ks1=%h out=%h", in_data, ks1, out_data);
        if ((out_data & 128'h0000000000000000_ffffffffffffffff)
            !== ((in_data ^ ks1) & 128'h0000000000000000_ffffffffffffffff)) begin
            $error("CTR block1 mismatch with tkeep exp=%h got=%h",
                   ((in_data ^ ks1) & 128'h0000000000000000_ffffffffffffffff),
                   (out_data & 128'h0000000000000000_ffffffffffffffff));
            failed = 1;
        end else begin
            $display("[TB] Block1 OK (partial)");
        end

        if (failed) begin
            $fatal(1, "AES-CTR core streaming test FAILED");
        end else begin
            $display("AES-CTR core streaming test PASS");
        end
        #20 $finish;
    end
endmodule
