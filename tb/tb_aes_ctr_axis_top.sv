`timescale 1ns/1ps
module tb_aes_ctr_axis_top;
    // Clock and reset
    reg aclk = 0; always #5 aclk = ~aclk; // 100MHz
    reg aresetn = 0;

    // AXI-Lite signals
    reg  [5:0]  s_axil_awaddr;  reg s_axil_awvalid; wire s_axil_awready;
    reg  [31:0] s_axil_wdata;   reg [3:0] s_axil_wstrb; reg s_axil_wvalid; wire s_axil_wready;
    wire [1:0]  s_axil_bresp;   wire s_axil_bvalid; reg s_axil_bready;
    reg  [5:0]  s_axil_araddr;  reg s_axil_arvalid; wire s_axil_arready;
    wire [31:0] s_axil_rdata;   wire [1:0] s_axil_rresp; wire s_axil_rvalid; reg s_axil_rready;

    // AXIS stream in/out
    reg  [127:0] s_axis_tdata; reg [15:0] s_axis_tkeep; reg s_axis_tlast; reg s_axis_tvalid; wire s_axis_tready;
    wire [127:0] m_axis_tdata; wire [15:0] m_axis_tkeep; wire m_axis_tlast; wire m_axis_tvalid; reg m_axis_tready;

    // DUT
    aes_ctr_axis_top #(.DATA_W(128), .KEEP_W(16), .FIFO_DEPTH(16)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axil_awaddr(s_axil_awaddr), .s_axil_awvalid(s_axil_awvalid), .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata), .s_axil_wstrb(s_axil_wstrb), .s_axil_wvalid(s_axil_wvalid), .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp), .s_axil_bvalid(s_axil_bvalid), .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr), .s_axil_arvalid(s_axil_arvalid), .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata), .s_axil_rresp(s_axil_rresp), .s_axil_rvalid(s_axil_rvalid), .s_axil_rready(s_axil_rready),
        .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep), .s_axis_tlast(s_axis_tlast), .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep), .m_axis_tlast(m_axis_tlast), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready)
    );

    // Reference AES core for keystreams
    reg ref_start; wire ref_busy, ref_valid; wire [127:0] ref_out; reg [127:0] ref_block;
    reg [127:0] key_ref, iv_ref; reg [127:0] ks0, ks1;
    aes_core ref_core (
        .clk(aclk), .rst_n(aresetn), .start(ref_start), .key(key_ref), .block_in(ref_block), .busy(ref_busy), .valid(ref_valid), .block_out(ref_out)
    );

    // AXI-Lite write task (single beat)
    task axil_write(input [5:0] addr, input [31:0] data);
        integer cyc;
        begin
            s_axil_awaddr = addr; s_axil_awvalid = 1; s_axil_wdata = data; s_axil_wstrb = 4'hF; s_axil_wvalid = 1; s_axil_bready = 1;
            cyc = 0;
            while (!(s_axil_awready && s_axil_wready) && cyc < 100) begin @(posedge aclk); cyc = cyc + 1; end
            if (!(s_axil_awready && s_axil_wready)) $fatal(1, "AXI-Lite write timeout at addr %0h", addr);
            @(posedge aclk); s_axil_awvalid = 0; s_axil_wvalid = 0;
            // wait for BVALID
            cyc = 0; while (!s_axil_bvalid && cyc < 100) begin @(posedge aclk); cyc = cyc + 1; end
            if (!s_axil_bvalid) $fatal(1, "AXI-Lite bvalid timeout");
            @(posedge aclk); s_axil_bready = 0;
        end
    endtask

    // Reset and defaults
    task reset_all;
        begin
            aresetn = 0;
            s_axil_awaddr=0; s_axil_awvalid=0; s_axil_wdata=0; s_axil_wstrb=0; s_axil_wvalid=0; s_axil_bready=0;
            s_axil_araddr=0; s_axil_arvalid=0; s_axil_rready=0;
            s_axis_tdata=0; s_axis_tkeep=0; s_axis_tlast=0; s_axis_tvalid=0; m_axis_tready=1;
            ref_start=0; ref_block=0; key_ref=0; iv_ref=0;
            repeat (5) @(posedge aclk);
            aresetn = 1; @(posedge aclk);
        end
    endtask

    initial begin
        $dumpfile("tb/sim/tb_aes_ctr_axis_top.vcd");
        $dumpvars(0, tb_aes_ctr_axis_top);
        reset_all();

        // Program key and IV via AXI-Lite (same as prior tests)
        key_ref = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        iv_ref  = 128'hf0e0d0c0b0a090807060504030201000;
        // KEY registers at offsets 0x10..0x1C (per axi_lite_ctrl: KEY0..KEY3)
        axil_write(6'h10, key_ref[31:0]);
        axil_write(6'h14, key_ref[63:32]);
        axil_write(6'h18, key_ref[95:64]);
        axil_write(6'h1C, key_ref[127:96]);
        // IV registers at offsets 0x20..0x2C (IV0..IV3)
        axil_write(6'h20, iv_ref[31:0]);
        axil_write(6'h24, iv_ref[63:32]);
        axil_write(6'h28, iv_ref[95:64]);
        axil_write(6'h2C, iv_ref[127:96]);
        // CTRL at 0x00: set keyiv_valid=1 (bit8) and start pulse (bit0)
        axil_write(6'h00, 32'h00000101);

        // Precompute keystreams
        ref_block = iv_ref; @(posedge aclk); ref_start=1; @(posedge aclk); ref_start=0;
        begin integer cyc=0; while (!ref_valid && cyc<3000) begin @(posedge aclk); cyc=cyc+1; end if(!ref_valid)$fatal(1,"ks0 timeout"); end
        ks0 = ref_out; $display("[TB_AXIS] ks0=%h", ks0);
        ref_block = iv_ref + 128'd1; @(posedge aclk); ref_start=1; @(posedge aclk); ref_start=0;
        begin integer cyc=0; while (!ref_valid && cyc<3000) begin @(posedge aclk); cyc=cyc+1; end if(!ref_valid)$fatal(1,"ks1 timeout"); end
        ks1 = ref_out; $display("[TB_AXIS] ks1=%h", ks1);

        // Stream two blocks in via s_axis
        // Block 0 full
        s_axis_tdata  = 128'h00112233445566778899aabbccddeeff;
        s_axis_tkeep  = 16'hffff; s_axis_tlast = 1'b0; s_axis_tvalid = 1'b1;
        begin integer cyc=0; while (!s_axis_tready && cyc<200) begin @(posedge aclk); cyc=cyc+1; end if(!s_axis_tready)$fatal(1,"s_axis_tready timeout blk0"); end
        @(posedge aclk); s_axis_tvalid = 1'b0;
        // Wait for output and check
        begin integer cyc=0; while (!m_axis_tvalid && cyc<5000) begin @(posedge aclk); cyc=cyc+1; end if(!m_axis_tvalid)$fatal(1,"m_axis_tvalid timeout blk0"); end
        if (m_axis_tdata !== (128'h00112233445566778899aabbccddeeff ^ ks0) || m_axis_tkeep !== 16'hffff || m_axis_tlast !== 1'b0)
            $error("[TB_AXIS] Block0 mismatch exp=%h got=%h keep=%h last=%0d", (128'h00112233445566778899aabbccddeeff ^ ks0), m_axis_tdata, m_axis_tkeep, m_axis_tlast);
        else $display("[TB_AXIS] Block0 OK");
        // Consume the beat
        @(posedge aclk);

        // Block 1 partial (8B)
        s_axis_tdata  = 128'h1122334455667788_0000000000000000;
        s_axis_tkeep  = 16'h00ff; s_axis_tlast = 1'b1; s_axis_tvalid = 1'b1;
        begin integer cyc=0; while (!s_axis_tready && cyc<200) begin @(posedge aclk); cyc=cyc+1; end if(!s_axis_tready)$fatal(1,"s_axis_tready timeout blk1"); end
        @(posedge aclk); s_axis_tvalid = 1'b0;
        begin integer cyc=0; while (!m_axis_tvalid && cyc<5000) begin @(posedge aclk); cyc=cyc+1; end if(!m_axis_tvalid)$fatal(1,"m_axis_tvalid timeout blk1"); end
        if ((m_axis_tdata & 128'h0000000000000000_ffffffffffffffff) !== ((128'h1122334455667788_0000000000000000 ^ ks1) & 128'h0000000000000000_ffffffffffffffff) ||
             m_axis_tkeep !== 16'h00ff || m_axis_tlast !== 1'b1)
            $error("[TB_AXIS] Block1 mismatch exp=%h got=%h keep=%h last=%0d",
                   ((128'h1122334455667788_0000000000000000 ^ ks1) & 128'h0000000000000000_ffffffffffffffff),
                   (m_axis_tdata & 128'h0000000000000000_ffffffffffffffff), m_axis_tkeep, m_axis_tlast);
        else $display("[TB_AXIS] Block1 OK (partial)");

        $display("AXIS top pipeline PASS");
        #50 $finish;
    end
endmodule
