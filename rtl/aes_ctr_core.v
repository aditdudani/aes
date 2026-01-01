// AES-128 CTR mode core with block-level handshake and tkeep/tlast
module aes_ctr_core(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] key,
    input  wire [127:0] iv,
    // input block interface
    input  wire         in_valid,
    output wire         in_ready,
    input  wire [127:0] in_data,
    input  wire [15:0]  in_keep,
    input  wire         in_last,
    // output block interface
    output reg          out_valid,
    input  wire         out_ready,
    output reg  [127:0] out_data,
    output reg  [15:0]  out_keep,
    output reg          out_last,
    // status
    output reg  [63:0]  blocks_processed,
    output reg          busy
);
    // Verilog FSM encoding with integer constants for linter compatibility
    localparam integer CTRIDLE = 0,
                       CTRWAIT = 1,
                       CTROUT  = 2;
    reg [1:0] cstate;

    reg [127:0] ctr_reg;
    reg [127:0] in_data_r;
    reg [15:0]  in_keep_r;
    reg         in_last_r;

    // AES core generates keystream = AES_enc(ctr_reg)
    reg         a_start;
    wire        a_busy, a_valid;
    wire [127:0] keystream;
    aes_core u_aes(
        .clk(clk), .rst_n(rst_n), .start(a_start),
        .key(key), .block_in(ctr_reg),
        .busy(a_busy), .valid(a_valid), .block_out(keystream)
    );

    // Prevent accepting input on the exact cycle 'start' is asserted.
    // Otherwise, if 'start' and 'in_valid' are both true in CTRIDLE,
    // the core would prioritize 'start' and drop the input while AXIS
    // handshakes it away. Gating ready avoids losing the first block.
    assign in_ready = (cstate == CTRIDLE) && !start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cstate            <= CTRIDLE;
            ctr_reg           <= 128'd0;
            in_data_r         <= 128'd0;
            in_keep_r         <= 16'd0;
            in_last_r         <= 1'b0;
            a_start           <= 1'b0;
            out_valid         <= 1'b0;
            out_data          <= 128'd0;
            out_keep          <= 16'd0;
            out_last          <= 1'b0;
            blocks_processed  <= 64'd0;
            busy              <= 1'b0;
        end else begin
            a_start <= 1'b0;
            case (cstate)
                CTRIDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        ctr_reg <= iv;
                        cstate  <= CTRIDLE;
                        blocks_processed <= 64'd0;
                        busy <= 1'b1;
`ifdef DEBUG_CTR
                        $display("[CTR] START: iv=%h", iv);
`endif
                    end else if (in_valid) begin
                        // Latch input block and fire AES on current counter
                        // Note: use "else if" to ensure counter is set before accepting data
                        in_data_r <= in_data;
                        in_keep_r <= in_keep;
                        in_last_r <= in_last;
                        a_start   <= 1'b1;
                        cstate    <= CTRWAIT;
`ifdef DEBUG_CTR
                        $display("[CTR] IN   : data=%h keep=%h last=%0d ctr=%h",
                                 in_data, in_keep, in_last, ctr_reg);
`endif
                    end
                end
                CTRWAIT: begin
                    busy <= 1'b1;
                    if (a_valid) begin
                        // XOR keystream with input block and present output
                        out_data  <= keystream ^ in_data_r;
                        out_keep  <= in_keep_r;
                        out_last  <= in_last_r;
                        out_valid <= 1'b1;
                        // Prepare next counter
                        ctr_reg   <= ctr_reg + 128'd1;
                        blocks_processed <= blocks_processed + 1'b1;
                        cstate    <= CTROUT;
`ifdef DEBUG_CTR
                        $display("[CTR] XOR  : ks=%h", keystream);
                        $display("[CTR] OUT  : out=%h next_ctr=%h",
                                 (keystream ^ in_data_r), ctr_reg + 128'd1);
`endif
                    end
                end
                CTROUT: begin
                    busy <= 1'b1;
                    if (out_valid && out_ready) begin
                        out_valid <= 1'b0;
                        cstate    <= CTRIDLE;
`ifdef DEBUG_CTR
                        $display("[CTR] OUT  : keep=%h last=%0d", out_keep, out_last);
`endif
                    end
                end
                default: cstate <= CTRIDLE;
            endcase
        end
    end
endmodule
