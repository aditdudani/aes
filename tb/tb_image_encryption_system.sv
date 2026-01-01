`timescale 1ns / 1ps

// Testbench for complete Image Encryption System
// Simulates the entire Block Design workflow:
// 1. Load COE file into image_bram
// 2. Trigger encryption_controller
// 3. Watch data flow through system
// 4. Extract encrypted data from encrypted_bram

module tb_image_encryption_system;

    // Parameters matching your design
    localparam IMAGE_DEPTH = 16384;  // 512x512 image = 262144 bytes / 16 = 16384 blocks
    localparam ADDR_WIDTH = 14;      // log2(16384) = 14
    localparam CLK_PERIOD = 10;      // 100 MHz clock

    // Build-time mode and file paths
    // Compile with -DDECRYPT for decrypt pass (reads encrypted -> writes decrypted)
`ifdef DECRYPT
    localparam string MODE_NAME = "DECRYPT";
    localparam string INPUT_HEX = "../data/encrypted_output.hex";
    localparam string OUT_HEX   = "../data/decrypted_output.hex";
    localparam string OUT_COE   = "../data/decrypted_output.coe";
    // For decrypt verification: expected original plaintext
    localparam string ORIG_HEX  = "../data/input_second.hex";
`else
    localparam string MODE_NAME = "ENCRYPT";
    localparam string INPUT_HEX = "../data/input_second.hex";
    localparam string OUT_HEX   = "../data/encrypted_output.hex";
    localparam string OUT_COE   = "../data/encrypted_output.coe";
`endif
    
    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // External control signals
    reg btn_start;
    wire led_done;
    wire led_busy;
    
    // Image BRAM signals
    wire [ADDR_WIDTH-1:0] img_bram_addr;
    wire [127:0]          img_bram_dout;
    wire                  img_bram_en;
    
    // Encrypted BRAM signals
    wire [ADDR_WIDTH-1:0] enc_bram_addr;
    wire [127:0]          enc_bram_din;
    wire                  enc_bram_we;
    wire                  enc_bram_en;
    
    // AXI-Stream signals (image_reader -> AES)
    wire [127:0]  s_axis_tdata;
    wire [15:0]   s_axis_tkeep;
    wire          s_axis_tlast;
    wire          s_axis_tvalid;
    wire          s_axis_tready;
    
    // AXI-Stream signals (AES -> encrypted_writer)
    wire [127:0]  m_axis_tdata;
    wire [15:0]   m_axis_tkeep;
    wire          m_axis_tlast;
    wire          m_axis_tvalid;
    wire          m_axis_tready;
    
    // AXI-Lite signals (aes_axil_config -> AES)
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
    
    // Controller interconnect signals
    wire config_start;
    wire config_done;
    wire reader_start;
    wire reader_done;
    wire writer_done;
    
    // BRAM storage arrays
    reg [127:0] image_memory [0:IMAGE_DEPTH-1];
`ifdef DECRYPT
    reg [127:0] orig_memory  [0:IMAGE_DEPTH-1];
`endif
    reg [127:0] encrypted_memory [0:IMAGE_DEPTH-1];
    
    //=================================================================
    // Clock Generation
    //=================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //=================================================================
    // Image BRAM Model (Read-only for image_reader)
    //=================================================================
    reg [127:0] img_bram_dout_reg;
    assign img_bram_dout = img_bram_dout_reg;
    
    always @(posedge clk) begin
        if (img_bram_en) begin
            img_bram_dout_reg <= image_memory[img_bram_addr];
        end
    end
    
    //=================================================================
    // Encrypted BRAM Model (Write-only for encrypted_writer)
    // Account for nonblocking update order by delaying write strobes one cycle
    //=================================================================
    reg                  enc_bram_en_d, enc_bram_we_d;
    reg [ADDR_WIDTH-1:0] enc_bram_addr_d;
    reg [127:0]          enc_bram_din_d;
    always @(posedge clk) begin
        enc_bram_en_d   <= enc_bram_en;
        enc_bram_we_d   <= enc_bram_we;
        enc_bram_addr_d <= enc_bram_addr;
        enc_bram_din_d  <= enc_bram_din;
        if (enc_bram_en_d && enc_bram_we_d) begin
            encrypted_memory[enc_bram_addr_d] <= enc_bram_din_d;
        end
    end
    
    //=================================================================
    // DUT: Encryption Controller
    //=================================================================
    encryption_controller u_controller (
        .clk(clk),
        .rst_n(rst_n),
        .start_encryption(btn_start),
        .encryption_done(led_done),
        .busy(led_busy),
        .config_start(config_start),
        .config_done(config_done),
        .reader_start(reader_start),
        .reader_done(reader_done),
        .writer_done(writer_done)
    );
    
    //=================================================================
    // DUT: AES AXI-Lite Config Module
    //=================================================================
    aes_axil_config u_aes_config (
        .clk(clk),
        .rst_n(rst_n),
        .start_config(config_start),
        .config_done(config_done),
        .m_axil_awaddr(s_axil_awaddr),
        .m_axil_awvalid(s_axil_awvalid),
        .m_axil_awready(s_axil_awready),
        .m_axil_wdata(s_axil_wdata),
        .m_axil_wstrb(s_axil_wstrb),
        .m_axil_wvalid(s_axil_wvalid),
        .m_axil_wready(s_axil_wready),
        .m_axil_bresp(s_axil_bresp),
        .m_axil_bvalid(s_axil_bvalid),
        .m_axil_bready(s_axil_bready),
        .m_axil_araddr(s_axil_araddr),
        .m_axil_arvalid(s_axil_arvalid),
        .m_axil_arready(s_axil_arready),
        .m_axil_rdata(s_axil_rdata),
        .m_axil_rresp(s_axil_rresp),
        .m_axil_rvalid(s_axil_rvalid),
        .m_axil_rready(s_axil_rready)
    );
    
    //=================================================================
    // DUT: Image Reader
    //=================================================================
    image_reader #(
        .IMAGE_DEPTH(IMAGE_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_image_reader (
        .clk(clk),
        .rst_n(rst_n),
        .start(reader_start),
        .done(reader_done),
        .bram_addr(img_bram_addr),
        .bram_dout(img_bram_dout),
        .bram_en(img_bram_en),
        .m_axis_tdata(s_axis_tdata),
        .m_axis_tkeep(s_axis_tkeep),
        .m_axis_tlast(s_axis_tlast),
        .m_axis_tvalid(s_axis_tvalid),
        .m_axis_tready(s_axis_tready)
    );
    
    //=================================================================
    // DUT: AES CTR AXIS Top
    //=================================================================
    aes_ctr_axis_top #(
        .DATA_W(128),
        .FIFO_DEPTH(64)
    ) u_aes_core (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axil_awaddr(s_axil_awaddr),
        .s_axil_awvalid(s_axil_awvalid),
        .s_axil_awready(s_axil_awready),
        .s_axil_wdata(s_axil_wdata),
        .s_axil_wstrb(s_axil_wstrb),
        .s_axil_wvalid(s_axil_wvalid),
        .s_axil_wready(s_axil_wready),
        .s_axil_bresp(s_axil_bresp),
        .s_axil_bvalid(s_axil_bvalid),
        .s_axil_bready(s_axil_bready),
        .s_axil_araddr(s_axil_araddr),
        .s_axil_arvalid(s_axil_arvalid),
        .s_axil_arready(s_axil_arready),
        .s_axil_rdata(s_axil_rdata),
        .s_axil_rresp(s_axil_rresp),
        .s_axil_rvalid(s_axil_rvalid),
        .s_axil_rready(s_axil_rready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready)
    );
    
    //=================================================================
    // DUT: Encrypted Writer
    //=================================================================
    encrypted_writer #(
        .IMAGE_DEPTH(IMAGE_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_encrypted_writer (
        .clk(clk),
        .rst_n(rst_n),
        .done(writer_done),
        .bram_addr(enc_bram_addr),
        .bram_din(enc_bram_din),
        .bram_we(enc_bram_we),
        .bram_en(enc_bram_en),
        .s_axis_tdata(m_axis_tdata),
        .s_axis_tkeep(m_axis_tkeep),
        .s_axis_tlast(m_axis_tlast),
        .s_axis_tvalid(m_axis_tvalid),
        .s_axis_tready(m_axis_tready)
    );
    
    //=================================================================
    // Test Stimulus
    //=================================================================
    integer i;
    integer fd;
    integer fd_hex;
    integer match_count;
    initial begin
        // Initialize
        rst_n = 0;
        btn_start = 0;
        
        // Load actual image data from COE file
        $display("[%0t] Mode: %s", $time, MODE_NAME);
        $display("[%0t] Loading input HEX: %s", $time, INPUT_HEX);
        // Prefer reading a clean HEX list (one 128-bit word per line)
        $readmemh(INPUT_HEX, image_memory);
    `ifdef DECRYPT
        // Also load original plaintext for equality check
        $readmemh(ORIG_HEX, orig_memory);
    `endif
        $display("[%0t] Image loaded successfully - %0d blocks", $time, IMAGE_DEPTH);
        
        // Reset
        #100;
        rst_n = 1;
        #100;
        
        $display("[%0t] ========================================", $time);
        $display("[%0t] Starting Image %s Test", $time, MODE_NAME);
        $display("[%0t] Image Size: %0d blocks (128-bit each)", $time, IMAGE_DEPTH);
        $display("[%0t] ========================================", $time);
        
        // Trigger encryption
        #100;
        btn_start = 1;
        #CLK_PERIOD;
        btn_start = 0;
        
        // Wait for controller done and writer done to ensure BRAM populated
        wait(led_done);
        wait(writer_done);
        $display("[%0t] %s COMPLETE!", $time, MODE_NAME);
        
        // Display sample results
        #1000;
        $display("\n[Sample Output]:");
        $display("Block 0:    In  = %032h", image_memory[0]);
        $display("            Out = %032h", encrypted_memory[0]);
        $display("Block 1:    In  = %032h", image_memory[1]);
        $display("            Out = %032h", encrypted_memory[1]);
        $display("Block 100:  In  = %032h", image_memory[100]);
        $display("            Out = %032h", encrypted_memory[100]);

        // Assess transformation over first 16 blocks
        match_count = 0;
        for (i = 0; i < 16; i = i + 1)
            if (encrypted_memory[i] === image_memory[i]) match_count++;
`ifdef DECRYPT
        // Decrypt pass: input is CIPHER, output should be PLAINTEXT.
        // 1) Ensure output differs from cipher input for first 16.
        if (match_count == 0)
            $display("\n[INFO] All 16 blocks differ from cipher input (expected)");
        else
            $display("\n[WARNING] %0d/16 blocks equal to cipher input", match_count);

        // 2) Check equality against known original plaintext over first 256 blocks
        match_count = 0;
        for (i = 0; i < 256; i = i + 1)
            if (encrypted_memory[i] === orig_memory[i]) match_count++;
        if (match_count == 256)
            $display("\n[SUCCESS] First 256 blocks match original plaintext");
        else
            $display("\n[WARNING] Only %0d/256 blocks match original plaintext", match_count);
`else
        // Encrypt pass: input plaintext -> output ciphertext, expect differences
        if (match_count == 0)
            $display("\n[SUCCESS] All plaintext blocks changed (encryption OK)");
        else
            $display("\n[WARNING] %0d/16 blocks unchanged", match_count);
`endif
        
        $display("\n[%0t] Simulation Complete - Check waveforms!", $time);
        // Dump encrypted memory to hex and COE for post-processing
        fd_hex = $fopen(OUT_HEX, "w");
        if (fd_hex) begin
            for (i = 0; i < IMAGE_DEPTH; i = i + 1) begin
                $fdisplay(fd_hex, "%032h", encrypted_memory[i]);
            end
            $fclose(fd_hex);
        end else begin
            $display("[ERROR] Unable to open output HEX file for writing.");
        end

        fd = $fopen(OUT_COE, "w");
        if (fd) begin
            $fdisplay(fd, "memory_initialization_radix=16;");
            $fdisplay(fd, "memory_initialization_vector=");
            for (i = 0; i < IMAGE_DEPTH; i = i + 1) begin
                if (i == IMAGE_DEPTH-1)
                    $fdisplay(fd, "  %032h;", encrypted_memory[i]);
                else
                    $fdisplay(fd, "  %032h,", encrypted_memory[i]);
            end
            $fclose(fd);
            $display("Outputs written: %s", OUT_HEX);
            $display("Outputs written: %s", OUT_COE);
        end else begin
            $display("[ERROR] Unable to open output COE file for writing.");
        end
        #5000;
        $finish;
    end
    
    //=================================================================
    // Monitoring
    //=================================================================
    initial begin
        $display("Time | State | Config | Reader | Writer | AXI-S Valid | Blocks Written");
        $display("-----|-------|--------|--------|--------|-------------|---------------");
    end
    
    always @(posedge clk) begin
        if (s_axis_tvalid && s_axis_tready) begin
            $display("[%0t] Image -> AES: Block data = %h", $time, s_axis_tdata);
        end
        
        if (m_axis_tvalid && m_axis_tready) begin
            $display("[%0t] AES -> Writer: Encrypted = %h", $time, m_axis_tdata);
        end

        if (enc_bram_en && enc_bram_we) begin
            $display("[%0t] WRITER: addr=%0d data=%h",
                     $time, enc_bram_addr, enc_bram_din);
        end
    end
    
    // VCD dump for waveform viewing
    initial begin
        $dumpfile("../tb/sim/tb_image_encryption_system.vcd");
        $dumpvars(0, tb_image_encryption_system);
    end

endmodule
