// Thin glue: AXIS slave to AES-CTR core input handshake
module axis_to_aes_if #(
    parameter integer DATA_W = 128,
    parameter integer KEEP_W = DATA_W/8
)(
    input  wire                 clk,
    input  wire                 rst_n,
    // AXIS slave side
    input  wire [DATA_W-1:0]    s_tdata,
    input  wire [KEEP_W-1:0]    s_tkeep,
    input  wire                 s_tlast,
    input  wire                 s_tvalid,
    output wire                 s_tready,
    // AES core input side
    output wire                 in_valid,
    input  wire                 in_ready,
    output wire [DATA_W-1:0]    in_data,
    output wire [KEEP_W-1:0]    in_keep,
    output wire                 in_last
);
    assign in_valid = s_tvalid;
    assign s_tready = in_ready;
    assign in_data  = s_tdata;
    assign in_keep  = s_tkeep;
    assign in_last  = s_tlast;
endmodule
