`timescale 1ns/1ps

// Small, fast pipeline test: image_reader -> AES CTR AXIS -> encrypted_writer
// Avoids the full controller; directly sequences config then streaming.

module tb_pipeline_small;
    localparam IMAGE_DEPTH = 64;
    localparam ADDR_WIDTH  = 6;   // log2(64)
    localparam CLK_PERIOD  = 10;

    // Clock & reset
    reg clk; reg rst_n;
    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    // AXI-Lite between config and AES
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

    // Stream in/out
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

    // BRAM-like models
    wire [ADDR_WIDTH-1:0] img_bram_addr;
    wire [127:0]          img_bram_dout;
    wire                  img_bram_en;
    wire [ADDR_WIDTH-1:0] enc_bram_addr;
    wire [127:0]          enc_bram_din;
    wire                  enc_bram_we;
    wire                  enc_bram_en;

    // Simple control signals
    reg  start_config;
    wire config_done;
    reg  reader_start;
    wire reader_done;
    wire writer_done;

    // Memories
    reg [127:0] image_mem [0:IMAGE_DEPTH-1];
    reg [127:0] out_mem   [0:IMAGE_DEPTH-1];

    // Image BRAM model
    reg [127:0] img_bram_dout_reg; assign img_bram_dout = img_bram_dout_reg;
    always @(posedge clk) if (img_bram_en) img_bram_dout_reg <= image_mem[img_bram_addr];

    // Encrypted BRAM model with one-cycle delayed strobe to match nonblocking semantics
    reg                  enc_bram_en_d, enc_bram_we_d;
    reg [ADDR_WIDTH-1:0] enc_bram_addr_d; reg [127:0] enc_bram_din_d;
    always @(posedge clk) begin
        enc_bram_en_d   <= enc_bram_en;
        enc_bram_we_d   <= enc_bram_we;
        enc_bram_addr_d <= enc_bram_addr;
        enc_bram_din_d  <= enc_bram_din;
        if (enc_bram_en_d && enc_bram_we_d) out_mem[enc_bram_addr_d] <= enc_bram_din_d;
    end

    // Config block
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

    // AES top
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
    initial begin
        rst_n = 0; start_config = 0; reader_start = 0;
        // Load small synthetic input
        $display("[%0t] Loading ../src/input_small.hex (64 blocks)", $time);
        $readmemh("../src/input_small.hex", image_mem);
        #100; rst_n = 1; #50;

        // Kick config
        $display("[%0t] Starting config...", $time);
        start_config = 1; #CLK_PERIOD; start_config = 0;
        wait(config_done);
        $display("[%0t] Config done. Delay before reader start...", $time);
        #200; // small guard delay

        // Start reader
        reader_start = 1; #CLK_PERIOD; reader_start = 0;

        // Wait for writer to finish
        wait(writer_done);
        $display("[%0t] SMALL ENCRYPT COMPLETE", $time);
        // Wait for final write to commit
        #100000;

        // Show first few words
        for (i = 0; i < 4; i = i + 1) begin
            $display("Block %0d: in=%032h out=%032h", i, image_mem[i], out_mem[i]);
        end

        // Write hex output
        fd_hex = $fopen("../src/small_encrypted.hex", "w");
        if (fd_hex) begin
            for (i = 0; i < IMAGE_DEPTH; i = i + 1) $fdisplay(fd_hex, "%032h", out_mem[i]);
            $fclose(fd_hex);
            $display("Wrote ../src/small_encrypted.hex");
        end
        #200; $finish;
    end

    // Debug: writer transactions
    always @(posedge clk) begin
        if (enc_bram_en && enc_bram_we) begin
            $display("[%0t] WRITER: addr=%0d data=%h", $time, enc_bram_addr, enc_bram_din);
        end
    end

    initial begin
        $dumpfile("sim/tb_pipeline_small.vcd");
        $dumpvars(0, tb_pipeline_small);
    end
endmodule
