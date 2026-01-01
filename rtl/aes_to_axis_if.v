// Thin glue: AES-CTR core output handshake to AXIS master
module aes_to_axis_if #(
    parameter integer DATA_W = 128,
    parameter integer KEEP_W = DATA_W/8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    // AES core output side
    input  wire                 out_valid,
    output wire                 out_ready,
    input  wire [DATA_W-1:0]    out_data,
    input  wire [KEEP_W-1:0]    out_keep,
    input  wire                 out_last,
    // AXIS master side
    output wire [DATA_W-1:0]    m_tdata,
    output wire [KEEP_W-1:0]    m_tkeep,
    output wire                 m_tlast,
    output wire                 m_tvalid,
    input  wire                 m_tready
);
    assign m_tdata  = out_data;
    assign m_tkeep  = out_keep;
    assign m_tlast  = out_last;
    assign m_tvalid = out_valid;
    assign out_ready = m_tready;
endmodule
