// Simple AXI-Stream FIFO (synchronous), parameterizable width and depth
module axis_fifo #(
    parameter integer DATA_W = 128,
    parameter integer KEEP_W = DATA_W/8,
    parameter integer DEPTH  = 512
)(
    input  wire                 clk,
    input  wire                 rst_n,
    // AXIS slave (input)
    input  wire [DATA_W-1:0]    s_tdata,
    input  wire [KEEP_W-1:0]    s_tkeep,
    input  wire                 s_tlast,
    input  wire                 s_tvalid,
    output wire                 s_tready,
    // AXIS master (output)
    output wire [DATA_W-1:0]    m_tdata,
    output wire [KEEP_W-1:0]    m_tkeep,
    output wire                 m_tlast,
    output wire                 m_tvalid,
    input  wire                 m_tready,
    // status
    output wire [AW:0]          level
);
    // verilog_lint: waive unpacked-dimensions-range-ordering -- Verilog-2001 requires [0:N-1] form
    (* ram_style = "block" *) reg [DATA_W-1:0] mem_data [0:DEPTH-1];
    // verilog_lint: waive unpacked-dimensions-range-ordering -- Verilog-2001 requires [0:N-1] form
    (* ram_style = "block" *) reg [KEEP_W-1:0] mem_keep [0:DEPTH-1];
    // verilog_lint: waive unpacked-dimensions-range-ordering -- Verilog-2001 requires [0:N-1] form
    (* ram_style = "block" *) reg              mem_last [0:DEPTH-1];

    // clog2 function for pointer width
    function automatic integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value-1; i > 0; i = i >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    localparam integer AW = clog2(DEPTH);

    reg [AW:0] wr_ptr, rd_ptr; // one extra bit for full/empty

    wire empty = (wr_ptr == rd_ptr);
    wire full  = (wr_ptr[AW-1:0] == rd_ptr[AW-1:0]) && (wr_ptr[AW] != rd_ptr[AW]);

    assign s_tready = !full;
    assign m_tvalid = !empty;
    assign level    = wr_ptr - rd_ptr;

    assign m_tdata = mem_data[rd_ptr[AW-1:0]];
    assign m_tkeep = mem_keep[rd_ptr[AW-1:0]];
    assign m_tlast = mem_last[rd_ptr[AW-1:0]];

    // write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= { (AW+1){1'b0} };
        end else if (s_tvalid && s_tready) begin
            mem_data[wr_ptr[AW-1:0]] <= s_tdata;
            mem_keep[wr_ptr[AW-1:0]] <= s_tkeep;
            mem_last[wr_ptr[AW-1:0]] <= s_tlast;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= { (AW+1){1'b0} };
        end else if (m_tvalid && m_tready) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
endmodule
