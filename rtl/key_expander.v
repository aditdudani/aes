// AES-128 key schedule (iterative)
module key_expander(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         load,
    input  wire         next,
    input  wire [127:0] key_in,
    output reg  [127:0] key_out,
    output reg  [3:0]   round
);
    // Rcon for rounds 1..10
    function automatic [31:0] rcon;
        input [3:0] r;
        begin
            case (r)
                4'd1: rcon = 32'h01_00_00_00;
                4'd2: rcon = 32'h02_00_00_00;
                4'd3: rcon = 32'h04_00_00_00;
                4'd4: rcon = 32'h08_00_00_00;
                4'd5: rcon = 32'h10_00_00_00;
                4'd6: rcon = 32'h20_00_00_00;
                4'd7: rcon = 32'h40_00_00_00;
                4'd8: rcon = 32'h80_00_00_00;
                4'd9: rcon = 32'h1b_00_00_00;
                4'd10:rcon = 32'h36_00_00_00;
                default: rcon = 32'h00_00_00_00;
            endcase
        end
    endfunction

    // rotword(w3)
    wire [31:0] rotw3;
    // subword(rotw3)
    wire [7:0] sw0, sw1, sw2, sw3;
    aes_sbox sbox0(.a(rotw3[31:24]), .y(sw3));
    aes_sbox sbox1(.a(rotw3[23:16]), .y(sw2));
    aes_sbox sbox2(.a(rotw3[15:8]),  .y(sw1));
    aes_sbox sbox3(.a(rotw3[7:0]),   .y(sw0));
    wire [31:0] sub_rotw3 = {sw3, sw2, sw1, sw0};

    wire [31:0] w0 = key_out[127:96];
    wire [31:0] w1 = key_out[95:64];
    wire [31:0] w2 = key_out[63:32];
    wire [31:0] w3 = key_out[31:0];
    assign rotw3 = {w3[23:0], w3[31:24]};

    wire [31:0] temp = sub_rotw3 ^ rcon(round + 4'd1);
    wire [31:0] nw0  = w0 ^ temp;
    wire [31:0] nw1  = w1 ^ nw0;
    wire [31:0] nw2  = w2 ^ nw1;
    wire [31:0] nw3  = w3 ^ nw2;
    wire [127:0] next_key = {nw0, nw1, nw2, nw3};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_out <= 128'b0;
            round   <= 4'd0;
        end else if (load) begin
            key_out <= key_in;
            round   <= 4'd0;
        end else if (next) begin
            key_out <= next_key;
            round   <= round + 1'b1;
        end
    end
endmodule
