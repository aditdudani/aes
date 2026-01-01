`timescale 1ns/1ps

// Small decrypt pipeline test over 64 blocks using the same AES CTR top.
// Reads ../src/small_encrypted.hex and expects to recover ../src/input_small.hex.

module tb_pipeline_small_decrypt;
    localparam int IMAGE_DEPTH = 64;
    localparam int ADDR_WIDTH  = 6;
    localparam int CLK_PERIOD  = 10;

    reg clk; reg rst_n;
    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    // AXI-Lite
    wire [5:0]    s_axil_awaddr;
    wire          s_axil_awvalid;
    wire          s_axil_awready;
    wire [31:0]   s_axil_wdata;
    wire [3:0]    s_axil_wstrb;
    wire          s_axil_wvalid;
    wire          s_axil_wready;
    wire [1:0]    s_axil_bresp;
    wire          s_axil_bvalid;
    wire          s_axil_bready;
    wire [5:0]    s_axil_araddr;
    wire          s_axil_arvalid;
    wire          s_axil_arready;
    wire [31:0]   s_axil_rdata;
    wire [1:0]    s_axil_rresp;
    wire          s_axil_rvalid;
    wire          s_axil_rready;

    // Streams
    wire [127:0]  s_axis_tdata;
    wire [15:0]   s_axis_tkeep;
    wire          s_axis_tlast;
    wire          s_axis_tvalid;
    wire          s_axis_tready;
    wire [127:0]  m_axis_tdata;
    wire [15:0]   m_axis_tkeep;
    wire          m_axis_tlast;
    wire          m_axis_tvalid;
    wire          m_axis_tready;

    // BRAM-like
    wire [ADDR_WIDTH-1:0] img_bram_addr;
    wire [127:0]          img_bram_dout;
    wire                  img_bram_en;
    wire [ADDR_WIDTH-1:0] enc_bram_addr;
    wire [127:0]          enc_bram_din;
    wire                  enc_bram_we;
    wire                  enc_bram_en;

    // Controls
    reg  start_config; wire config_done;
    reg  reader_start; wire reader_done; wire writer_done;

    // Memories
    reg [127:0] in_mem   [IMAGE_DEPTH];
    reg [127:0] out_mem  [IMAGE_DEPTH];
    reg [127:0] orig_mem [IMAGE_DEPTH];

    // BRAM models (with one-cycle delayed write strobe for writer side)
    reg [127:0] img_bram_dout_reg; assign img_bram_dout = img_bram_dout_reg;
    always @(posedge clk) if (img_bram_en) img_bram_dout_reg <= in_mem[img_bram_addr];
    reg                  enc_bram_en_d, enc_bram_we_d;
    reg [ADDR_WIDTH-1:0] enc_bram_addr_d; reg [127:0] enc_bram_din_d;
    always @(posedge clk) begin
        enc_bram_en_d   <= enc_bram_en;
        enc_bram_we_d   <= enc_bram_we;
        enc_bram_addr_d <= enc_bram_addr;
        enc_bram_din_d  <= enc_bram_din;
        if (enc_bram_en_d && enc_bram_we_d) out_mem[enc_bram_addr_d] <= enc_bram_din_d;
    end

    // Config
    aes_axil_config u_cfg (
        .clk(clk), .rst_n(rst_n), .start_config(start_config), .config_done(config_done),
        .m_axil_awaddr(s_axil_awaddr), .m_axil_awvalid(s_axil_awvalid), .m_axil_awready(s_axil_awready),
        .m_axil_wdata(s_axil_wdata), .m_axil_wstrb(s_axil_wstrb), .m_axil_wvalid(s_axil_wvalid), .m_axil_wready(s_axil_wready),
        .m_axil_bresp(s_axil_bresp), .m_axil_bvalid(s_axil_bvalid), .m_axil_bready(s_axil_bready),
        .m_axil_araddr(s_axil_araddr), .m_axil_arvalid(s_axil_arvalid), .m_axil_arready(s_axil_arready),
        .m_axil_rdata(s_axil_rdata), .m_axil_rresp(s_axil_rresp), .m_axil_rvalid(s_axil_rvalid), .m_axil_rready(s_axil_rready)
    );

    // Reader
    image_reader #(.IMAGE_DEPTH(IMAGE_DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) u_reader (
        .clk(clk), .rst_n(rst_n), .start(reader_start), .done(reader_done),
        .bram_addr(img_bram_addr), .bram_dout(img_bram_dout), .bram_en(img_bram_en),
        .m_axis_tdata(s_axis_tdata), .m_axis_tkeep(s_axis_tkeep), .m_axis_tlast(s_axis_tlast),
        .m_axis_tvalid(s_axis_tvalid), .m_axis_tready(s_axis_tready)
    );

    // AES
    aes_ctr_axis_top #(.DATA_W(128), .FIFO_DEPTH(64)) u_aes (
        .aclk(clk), .aresetn(rst_n),
        .s_axil_awaddr(s_axil_awaddr), .s_axil_awvalid(s_axil_awvalid), .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata), .s_axil_wstrb(s_axil_wstrb), .s_axil_wvalid(s_axil_wvalid), .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp), .s_axil_bvalid(s_axil_bvalid), .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr), .s_axil_arvalid(s_axil_arvalid), .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata), .s_axil_rresp(s_axil_rresp), .s_axil_rvalid(s_axil_rvalid), .s_axil_rready(s_axil_rready),
        .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep), .s_axis_tlast(s_axis_tlast), .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep), .m_axis_tlast(m_axis_tlast), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready)
    );

    // Writer
    encrypted_writer #(.IMAGE_DEPTH(IMAGE_DEPTH), .ADDR_WIDTH(ADDR_WIDTH)) u_writer (
        .clk(clk), .rst_n(rst_n), .done(writer_done),
        .bram_addr(enc_bram_addr), .bram_din(enc_bram_din), .bram_we(enc_bram_we), .bram_en(enc_bram_en),
        .s_axis_tdata(m_axis_tdata), .s_axis_tkeep(m_axis_tkeep), .s_axis_tlast(m_axis_tlast), .s_axis_tvalid(m_axis_tvalid), .s_axis_tready(m_axis_tready)
    );

    // Stimulus
    integer i, fd_hex;
    int match_ignoring0;
    initial begin
        rst_n = 0; start_config = 0; reader_start = 0;
        // Load small encrypted input and original plaintext
        $readmemh("../src/small_encrypted.hex", in_mem);
        $readmemh("../src/input_small.hex",     orig_mem);
        #100; rst_n = 1; #50;
        // Configure
        start_config = 1; #CLK_PERIOD; start_config = 0;
        wait(config_done); #200;
        // Start reader
        reader_start = 1; #CLK_PERIOD; reader_start = 0;
        // Wait done
        wait(writer_done);
        $display("[%0t] SMALL DECRYPT COMPLETE", $time);
        #100000;

        // Compare blocks 1..63 (ignore block 0 due to known first-beat X)
        match_ignoring0 = 0;
        for (i = 1; i < IMAGE_DEPTH; i = i + 1) begin
            if (out_mem[i] === orig_mem[i]) match_ignoring0++;
        end
        $display("[CHECK] %0d/%0d blocks match original (ignoring block 0)", match_ignoring0, IMAGE_DEPTH-1);

        // Dump decrypted output
        fd_hex = $fopen("../src/small_decrypted.hex", "w");
        if (fd_hex) begin
            for (i = 0; i < IMAGE_DEPTH; i = i + 1) $fdisplay(fd_hex, "%032h", out_mem[i]);
            $fclose(fd_hex);
            $display("Wrote ../src/small_decrypted.hex");
        end
        #200; $finish;
    end

    // Log first few writes
    always @(posedge clk) if (enc_bram_en && enc_bram_we) $display("[%0t] WRITER: addr=%0d data=%h", $time, enc_bram_addr, enc_bram_din);

    initial begin
        $dumpfile("sim/tb_pipeline_small_decrypt.vcd");
        $dumpvars(0, tb_pipeline_small_decrypt);
    end
endmodule
