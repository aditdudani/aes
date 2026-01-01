// AES-128 Encryption Core (iterative: 1 registered round per cycle)
module aes_core(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] key,
    input  wire [127:0] block_in,
    output reg          busy,
    output reg          valid,
    output reg  [127:0] block_out
);
    // State encoding (Verilog integers for linter compatibility)
    localparam integer STATEIDLE     = 0,
                       STATEINIT     = 1,
                       STATEADVKEY   = 2,
                       STATEKEYWAIT  = 3,
                       STATERUNEXEC  = 4,
                       STATERUNLATCH = 5,
                       STATEDONE     = 6;

    reg [2:0]    state;
    reg [3:0]    round_ctr; // 1..10
    reg [127:0]  st_reg;

    // Key expansion
    reg          k_load, k_next;
    wire [127:0] rk;
    wire [3:0]   rk_round;
    key_expander u_kexp(
        .clk(clk), .rst_n(rst_n),
        .load(k_load), .next(k_next),
        .key_in(key), .key_out(rk), .round(rk_round)
    );

    // Round function (registered)
    reg          r_en;
    reg          r_skip_mix;
    reg  [127:0] rk_reg;
    wire [127:0] r_state_out;
    aes_round u_round(
        .clk(clk), .en(r_en), .skip_mixcols(r_skip_mix),
        .state_in(st_reg), .round_key(rk_reg), .state_out(r_state_out)
    );

    // Byte-swap helpers (reverse 16-byte order) to reconcile external MSB-first
    // literals with internal LSB-first byte indexing used by submodules.
    function automatic [127:0] bswap128;
        input [127:0] x;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                bswap128[8*i +: 8] = x[127 - 8*i -: 8];
            end
        end
    endfunction

    wire [127:0] block_in_b = bswap128(block_in);
    wire [127:0] key_b      = bswap128(key);
    wire [127:0] rk_b       = bswap128(rk);
    wire [127:0] r_state_out_perm = bswap128(r_state_out);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= STATEIDLE;
            round_ctr  <= 4'd0;
            st_reg     <= 128'b0;
            busy       <= 1'b0;
            valid      <= 1'b0;
            block_out  <= 128'b0;
            k_load     <= 1'b0;
            k_next     <= 1'b0;
            r_en       <= 1'b0;
            r_skip_mix <= 1'b0;
            rk_reg     <= 128'b0;
        end else begin
            // defaults each cycle
            k_load <= 1'b0;
            k_next <= 1'b0;
            r_en   <= 1'b0;
            valid  <= 1'b0;

            case (state)
                STATEIDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        // Load key and do initial AddRoundKey
                        k_load    <= 1'b1;
                        // initial AddRoundKey in internal byte order
                        st_reg    <= block_in_b ^ key_b;
`ifdef DEBUG_AES
                        $display("[AES] START: block_in=%h key=%h", block_in, key);
                        $display("[AES] START: st0=block^key=%h", (block_in ^ key));
`endif
                        round_ctr <= 4'd1;
                        busy      <= 1'b1;
                        state     <= STATEINIT;
                    end
                end
                STATEINIT: begin
                    // Prepare to request round-1 key on the next clock edge
                    k_next <= 1'b1;
`ifdef DEBUG_AES
                    $display("[AES] INIT: st=%h", st_reg);
`endif
                    state  <= STATEADVKEY;
                end
                STATEADVKEY: begin
                    // Advance to KEYWAIT; key_expander samples 'next' on previous edge
                    state  <= STATEKEYWAIT;
                end
                STATEKEYWAIT: begin
                    // Latch the (now updated) round key for current round
                    rk_reg     <= rk_b;
                    // Arm the round for next clock edge
                    r_skip_mix <= (round_ctr == 4'd10);
                    r_en       <= 1'b1;
`ifdef DEBUG_AES
                    $display("[AES] KEYWAIT: round=%0d rk=%h (kexp r=%0d)",
                             round_ctr, rk, rk_round);
`endif
                    state      <= STATERUNEXEC;
                end
                STATERUNEXEC: begin
                    // Round captured at this edge by aes_round (en was high last cycle)
                    // Drop enable now and proceed to latch next cycle
                    r_en       <= 1'b0;
`ifdef DEBUG_AES
                    $display("[AES] EXEC  round=%0d skip=%0d", round_ctr, (round_ctr==10));
                    $display("[AES]   rk   =%h", rk_reg);
                    $display("[AES]   st_in=%h", st_reg);
`endif
                    state      <= STATERUNLATCH;
                end
                STATERUNLATCH: begin
                    // Latch the result of the previously executed round
                    st_reg <= r_state_out;
`ifdef DEBUG_AES
                    $display("[AES] LATCH round=%0d st_out=%h", round_ctr, r_state_out);
`endif
                    if (round_ctr == 4'd10) begin
                        block_out <= r_state_out_perm;
                        valid     <= 1'b1;
`ifdef DEBUG_AES
                        $display("[AES] DONE: block_out=%h", r_state_out_perm);
`endif
                        state     <= STATEDONE;
                    end else begin
                        // Prepare next round key (assert next this cycle, then wait one cycle)
                        round_ctr <= round_ctr + 1'b1;
                        k_next    <= 1'b1;
                        state     <= STATEADVKEY;
                    end
                end
                STATEDONE: begin
                    busy  <= 1'b0;
                    state <= STATEIDLE;
                end
                default: state <= STATEIDLE;
            endcase
        end
    end
endmodule
