// One AES encryption round
module aes_round(
    input  wire         clk,
    input  wire         en,
    input  wire         skip_mixcols, // 1 for final round
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output reg  [127:0] state_out
);
    wire [127:0] sb, sr, mc;

    aes_subbytes u_sb(.state_in(state_in), .state_out(sb));
    aes_shiftrows u_sr(.state_in(sb), .state_out(sr));
    aes_mixcolumns u_mc(.state_in(sr), .state_out(mc));

    wire [127:0] addrk_mix = mc ^ round_key;
    wire [127:0] addrk_nmix = sr ^ round_key;

    always @(posedge clk) begin
        if (en) begin
`ifdef DEBUG_AES
            $display("[ROUND] SB=%h", sb);
            $display("[ROUND] SR=%h", sr);
            if (!skip_mixcols) $display("[ROUND] MC=%h", mc);
            $display("[ROUND] RK=%h", round_key);
`endif
            state_out <= skip_mixcols ? addrk_nmix : addrk_mix;
        end
    end
endmodule
