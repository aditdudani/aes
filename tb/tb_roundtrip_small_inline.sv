`timescale 1ns/1ps

// Restored original style: two AES cores encrypt then decrypt streaming data loaded from input_small.hex
module tb_roundtrip_small_inline;
    localparam int IMAGE_DEPTH = 64;
    localparam int ADDR_WIDTH  = 6;
    localparam int CLK_PERIOD  = 10;

    reg clk; reg rst_n; initial begin clk=0; forever #(CLK_PERIOD/2) clk=~clk; end

    // AXI-Lite buses for two AES instances
    wire [5:0] awaddr1, awaddr2; wire awvalid1, awvalid2, awready1, awready2;
    wire [31:0] wdata1, wdata2; wire [3:0] wstrb1, wstrb2; wire wvalid1, wvalid2, wready1, wready2;
    wire [1:0] bresp1, bresp2; wire bvalid1, bvalid2; wire bready1, bready2;
    wire [5:0] araddr1, araddr2; wire arvalid1, arvalid2, arready1, arready2;
    wire [31:0] rdata1, rdata2; wire [1:0] rresp1, rresp2; wire rvalid1, rvalid2, rready1, rready2;

    // Stream between components
    wire [127:0] s_tdata; wire [15:0] s_tkeep; wire s_tlast, s_tvalid, s_tready;
    wire [127:0] mid_tdata; wire [15:0] mid_tkeep; wire mid_tlast, mid_tvalid, mid_tready;
    wire [127:0] m_tdata; wire [15:0] m_tkeep; wire m_tlast, m_tvalid, m_tready;

    // BRAM-like
    wire [ADDR_WIDTH-1:0] img_bram_addr; wire [127:0] img_bram_dout; wire img_bram_en;
    wire [ADDR_WIDTH-1:0] out_bram_addr; wire [127:0] out_bram_din; wire out_bram_we; wire out_bram_en;

    // Controls
    reg start_cfg1, start_cfg2; wire cfg_done1, cfg_done2; reg reader_start; wire reader_done; wire writer_done;

    // Memories
    reg [127:0] in_mem [0:IMAGE_DEPTH-1];
    reg [127:0] out_mem[0:IMAGE_DEPTH-1];
    reg [127:0] img_bram_dout_reg; assign img_bram_dout = img_bram_dout_reg;
    always @(posedge clk) if (img_bram_en) img_bram_dout_reg <= in_mem[img_bram_addr];
    always @(posedge clk) if (out_bram_en && out_bram_we) out_mem[out_bram_addr] <= out_bram_din;

    // Config blocks (same key/IV)
    aes_axil_config u_cfg1 (
        .clk(clk), .rst_n(rst_n), .start_config(start_cfg1), .config_done(cfg_done1),
        .m_axil_awaddr(awaddr1), .m_axil_awvalid(awvalid1), .m_axil_awready(awready1),
        .m_axil_wdata(wdata1), .m_axil_wstrb(wstrb1), .m_axil_wvalid(wvalid1), .m_axil_wready(wready1),
        .m_axil_bresp(bresp1), .m_axil_bvalid(bvalid1), .m_axil_bready(bready1),
        .m_axil_araddr(araddr1), .m_axil_arvalid(arvalid1), .m_axil_arready(arready1),
        .m_axil_rdata(rdata1), .m_axil_rresp(rresp1), .m_axil_rvalid(rvalid1), .m_axil_rready(rready1)
    );
    aes_axil_config u_cfg2 (
        .clk(clk), .rst_n(rst_n), .start_config(start_cfg2), .config_done(cfg_done2),
        .m_axil_awaddr(awaddr2), .m_axil_awvalid(awvalid2), .m_axil_awready(awready2),
        .m_axil_wdata(wdata2), .m_axil_wstrb(wstrb2), .m_axil_wvalid(wvalid2), .m_axil_wready(wready2),
        .m_axil_bresp(bresp2), .m_axil_bvalid(bvalid2), .m_axil_bready(bready2),
        .m_axil_araddr(araddr2), .m_axil_arvalid(arvalid2), .m_axil_arready(arready2),
        .m_axil_rdata(rdata2), .m_axil_rresp(rresp2), .m_axil_rvalid(rvalid2), .m_axil_rready(rready2)
    );

    // Reader
    image_reader #(.IMAGE_DEPTH(IMAGE_DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) u_reader (
        .clk(clk), .rst_n(rst_n), .start(reader_start), .done(reader_done),
        .bram_addr(img_bram_addr), .bram_dout(img_bram_dout), .bram_en(img_bram_en),
        .m_axis_tdata(s_tdata), .m_axis_tkeep(s_tkeep), .m_axis_tlast(s_tlast),
        .m_axis_tvalid(s_tvalid), .m_axis_tready(s_tready)
    );

    // AES #1 (encrypt)
    aes_ctr_axis_top #(.DATA_W(128), .FIFO_DEPTH(64)) u_aes_enc (
        .aclk(clk), .aresetn(rst_n),
        .s_axil_awaddr(awaddr1), .s_axil_awvalid(awvalid1), .s_axil_awready(awready1),
        .s_axil_wdata(wdata1), .s_axil_wstrb(wstrb1), .s_axil_wvalid(wvalid1), .s_axil_wready(wready1),
        .s_axil_bresp(bresp1), .s_axil_bvalid(bvalid1), .s_axil_bready(bready1),
        .s_axil_araddr(araddr1), .s_axil_arvalid(arvalid1), .s_axil_arready(arready1),
        .s_axil_rdata(rdata1), .s_axil_rresp(rresp1), .s_axil_rvalid(rvalid1), .s_axil_rready(rready1),
        .s_axis_tdata(s_tdata), .s_axis_tkeep(s_tkeep), .s_axis_tlast(s_tlast), .s_axis_tvalid(s_tvalid), .s_axis_tready(s_tready),
        .m_axis_tdata(mid_tdata), .m_axis_tkeep(mid_tkeep), .m_axis_tlast(mid_tlast), .m_axis_tvalid(mid_tvalid), .m_axis_tready(mid_tready)
    );

    // AES #2 (decrypt by XOR with same keystream)
    aes_ctr_axis_top #(.DATA_W(128), .FIFO_DEPTH(64)) u_aes_dec (
        .aclk(clk), .aresetn(rst_n),
        .s_axil_awaddr(awaddr2), .s_axil_awvalid(awvalid2), .s_axil_awready(awready2),
        .s_axil_wdata(wdata2), .s_axil_wstrb(wstrb2), .s_axil_wvalid(wvalid2), .s_axil_wready(wready2),
        .s_axil_bresp(bresp2), .s_axil_bvalid(bvalid2), .s_axil_bready(bready2),
        .s_axil_araddr(araddr2), .s_axil_arvalid(arvalid2), .s_axil_arready(arready2),
        .s_axil_rdata(rdata2), .s_axil_rresp(rresp2), .s_axil_rvalid(rvalid2), .s_axil_rready(rready2),
        .s_axis_tdata(mid_tdata), .s_axis_tkeep(mid_tkeep), .s_axis_tlast(mid_tlast), .s_axis_tvalid(mid_tvalid), .s_axis_tready(mid_tready),
        .m_axis_tdata(m_tdata), .m_axis_tkeep(m_tkeep), .m_axis_tlast(m_tlast), .m_axis_tvalid(m_tvalid), .m_axis_tready(m_tready)
    );

    // Writer
    encrypted_writer #(.IMAGE_DEPTH(IMAGE_DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) u_writer (
        .clk(clk), .rst_n(rst_n), .done(writer_done),
        .bram_addr(out_bram_addr), .bram_din(out_bram_din), .bram_we(out_bram_we), .bram_en(out_bram_en),
        .s_axis_tdata(m_tdata), .s_axis_tkeep(m_tkeep), .s_axis_tlast(m_tlast), .s_axis_tvalid(m_tvalid), .s_axis_tready(m_tready)
    );

    integer i; integer match_cnt;
    initial begin
        rst_n = 0; start_cfg1 = 0; start_cfg2 = 0; reader_start = 0;
        $readmemh("../src/input_small.hex", in_mem);
        #100; rst_n = 1; #50;
        start_cfg1 = 1; start_cfg2 = 1; #CLK_PERIOD; start_cfg1 = 0; start_cfg2 = 0;
        wait(cfg_done1); wait(cfg_done2); #200;
        reader_start = 1; #CLK_PERIOD; reader_start = 0;
        wait(writer_done);
        @(posedge clk); @(posedge clk);
        match_cnt = 0; for (i=0;i<IMAGE_DEPTH;i=i+1) if (out_mem[i] === in_mem[i]) match_cnt++;
        $display("[ROUNDTRIP] Matches including block 0: %0d/%0d", match_cnt, IMAGE_DEPTH);
        match_cnt = 0; for (i=1;i<IMAGE_DEPTH;i=i+1) if (out_mem[i] === in_mem[i]) match_cnt++;
        $display("[ROUNDTRIP] Matches ignoring block 0: %0d/%0d", match_cnt, IMAGE_DEPTH-1);
        #200; $finish;
    end

        initial begin
		$dumpfile("sim/tb_roundtrip_small_inline.vcd");
		$dumpvars(0, tb_roundtrip_small_inline);
        end
endmodule
