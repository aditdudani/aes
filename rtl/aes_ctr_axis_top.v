// Top-level: AXI-Lite control + AXI-Stream in/out around AES-CTR core
module aes_ctr_axis_top #(
    parameter integer DATA_W = 128,
    parameter integer KEEP_W = DATA_W/8,
    parameter integer FIFO_DEPTH = 64
)(
    input  wire                 aclk,
    input  wire                 aresetn,
    // AXI4-Lite control
    input  wire [5:0]           s_axil_awaddr,
    input  wire                 s_axil_awvalid,
    output wire                 s_axil_awready,
    input  wire [31:0]          s_axil_wdata,
    input  wire [3:0]           s_axil_wstrb,
    input  wire                 s_axil_wvalid,
    output wire                 s_axil_wready,
    output wire [1:0]           s_axil_bresp,
    output wire                 s_axil_bvalid,
    input  wire                 s_axil_bready,
    input  wire [5:0]           s_axil_araddr,
    input  wire                 s_axil_arvalid,
    output wire                 s_axil_arready,
    output wire [31:0]          s_axil_rdata,
    output wire [1:0]           s_axil_rresp,
    output wire                 s_axil_rvalid,
    input  wire                 s_axil_rready,
    // AXI-Stream slave (input from DMA MM2S)
    input  wire [DATA_W-1:0]    s_axis_tdata,
    input  wire [KEEP_W-1:0]    s_axis_tkeep,
    input  wire                 s_axis_tlast,
    input  wire                 s_axis_tvalid,
    output wire                 s_axis_tready,
    // AXI-Stream master (output to DMA S2MM)
    output wire [DATA_W-1:0]    m_axis_tdata,
    output wire [KEEP_W-1:0]    m_axis_tkeep,
    output wire                 m_axis_tlast,
    output wire                 m_axis_tvalid,
    input  wire                 m_axis_tready
);
    // CSR block
    wire               ctrl_start_pulse, ctrl_soft_reset, ctrl_keyiv_valid;
    wire [127:0]       key, iv;
    wire [15:0]        fifo_in_level, fifo_out_level;
    wire [63:0]        blocks_processed;
    wire               core_busy, core_error;

    axi_lite_ctrl #(.ADDR_W(6)) u_csr (
        .ACLK(aclk), .ARESETN(aresetn),
        .AWADDR(s_axil_awaddr), .AWVALID(s_axil_awvalid), .AWREADY(s_axil_awready),
        .WDATA(s_axil_wdata), .WSTRB(s_axil_wstrb), .WVALID(s_axil_wvalid), .WREADY(s_axil_wready),
        .BRESP(s_axil_bresp), .BVALID(s_axil_bvalid), .BREADY(s_axil_bready),
        .ARADDR(s_axil_araddr), .ARVALID(s_axil_arvalid), .ARREADY(s_axil_arready),
        .RDATA(s_axil_rdata), .RRESP(s_axil_rresp), .RVALID(s_axil_rvalid), .RREADY(s_axil_rready),
    .ctrl_start_pulse(ctrl_start_pulse),
    .ctrl_soft_reset(ctrl_soft_reset),
    .ctrl_keyiv_valid(ctrl_keyiv_valid),
        .key(key), .iv(iv),
        .sts_busy(core_busy), .sts_error(core_error),
        .sts_fifo_in_level(fifo_in_level), .sts_fifo_out_level(fifo_out_level),
        .sts_blocks_processed(blocks_processed)
    );

    // AXIS FIFOs
    wire [DATA_W-1:0]    in_tdata;
    wire [KEEP_W-1:0]    in_tkeep;
    wire                 in_tlast;
    wire                 in_tvalid;
    wire                 in_tready;

    wire [DATA_W-1:0]    out_tdata;
    wire [KEEP_W-1:0]    out_tkeep;
    wire                 out_tlast;
    wire                 out_tvalid;
    wire                 out_tready;

    axis_fifo #(.DATA_W(DATA_W), .KEEP_W(KEEP_W), .DEPTH(FIFO_DEPTH)) u_fifo_in (
        .clk(aclk), .rst_n(aresetn),
        .s_tdata(s_axis_tdata), .s_tkeep(s_axis_tkeep),
        .s_tlast(s_axis_tlast), .s_tvalid(s_axis_tvalid),
        .s_tready(s_axis_tready),
        .m_tdata(in_tdata), .m_tkeep(in_tkeep),
        .m_tlast(in_tlast), .m_tvalid(in_tvalid),
        .m_tready(in_tready),
        .level(fifo_in_level)
    );

    axis_fifo #(.DATA_W(DATA_W), .KEEP_W(KEEP_W), .DEPTH(FIFO_DEPTH)) u_fifo_out (
        .clk(aclk), .rst_n(aresetn),
        .s_tdata(out_tdata), .s_tkeep(out_tkeep),
        .s_tlast(out_tlast), .s_tvalid(out_tvalid),
        .s_tready(out_tready),
        .m_tdata(m_axis_tdata), .m_tkeep(m_axis_tkeep),
        .m_tlast(m_axis_tlast), .m_tvalid(m_axis_tvalid),
        .m_tready(m_axis_tready),
        .level(fifo_out_level)
    );

    // Glue
    wire in_blk_valid, in_blk_ready, in_blk_last;
    wire [DATA_W-1:0] in_blk_data;
    wire [KEEP_W-1:0] in_blk_keep;
    axis_to_aes_if #(.DATA_W(DATA_W)) u_in_if (
        .clk(aclk), .rst_n(aresetn),
        .s_tdata(in_tdata), .s_tkeep(in_tkeep),
        .s_tlast(in_tlast), .s_tvalid(in_tvalid),
        .s_tready(in_tready),
        .in_valid(in_blk_valid), .in_ready(in_blk_ready),
        .in_data(in_blk_data), .in_keep(in_blk_keep), .in_last(in_blk_last)
    );

    wire out_blk_valid, out_blk_ready, out_blk_last;
    wire [DATA_W-1:0] out_blk_data;
    wire [KEEP_W-1:0] out_blk_keep;
    aes_to_axis_if #(.DATA_W(DATA_W)) u_out_if (
        .clk(aclk), .rst_n(aresetn),
        .out_valid(out_blk_valid), .out_ready(out_blk_ready),
        .out_data(out_blk_data), .out_keep(out_blk_keep),
        .out_last(out_blk_last),
        .m_tdata(out_tdata), .m_tkeep(out_tkeep),
        .m_tlast(out_tlast), .m_tvalid(out_tvalid),
        .m_tready(out_tready)
    );

    // Core
    aes_ctr_core u_ctr (
        .clk(aclk), .rst_n(aresetn), .start(ctrl_start_pulse),
        .key(key), .iv(iv),
        .in_valid(in_blk_valid), .in_ready(in_blk_ready),
        .in_data(in_blk_data), .in_keep(in_blk_keep), .in_last(in_blk_last),
        .out_valid(out_blk_valid), .out_ready(out_blk_ready),
        .out_data(out_blk_data), .out_keep(out_blk_keep), .out_last(out_blk_last),
        .blocks_processed(blocks_processed), .busy(core_busy)
    );

    assign core_error = 1'b0; // placeholder, no internal errors wired yet
endmodule
