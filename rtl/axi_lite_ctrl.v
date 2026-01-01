// Minimal AXI4-Lite CSR block for AES-CTR control
module axi_lite_ctrl #(
    parameter integer ADDR_W = 6 // 64 bytes
)(
    input  wire         ACLK,
    input  wire         ARESETN,
    // AW channel
    input  wire [ADDR_W-1:0] AWADDR,
    input  wire              AWVALID,
    output reg               AWREADY,
    // W channel
    input  wire [31:0]       WDATA,
    input  wire [3:0]        WSTRB,
    input  wire              WVALID,
    output reg               WREADY,
    // B channel
    output reg  [1:0]        BRESP,
    output reg               BVALID,
    input  wire              BREADY,
    // AR channel
    input  wire [ADDR_W-1:0] ARADDR,
    input  wire              ARVALID,
    output reg               ARREADY,
    // R channel
    output reg [31:0]        RDATA,
    output reg [1:0]         RRESP,
    output reg               RVALID,
    input  wire              RREADY,

    // Control outputs
    output reg               ctrl_start_pulse,
    output reg               ctrl_soft_reset,
    output reg               ctrl_keyiv_valid,
    output reg  [127:0]      key,
    output reg  [127:0]      iv,

    // Status inputs
    input  wire              sts_busy,
    input  wire              sts_error,
    input  wire [15:0]       sts_fifo_in_level,
    input  wire [15:0]       sts_fifo_out_level,
    input  wire [63:0]       sts_blocks_processed
);
    // Registers
    reg [31:0] CTRL;
    reg [31:0] STATUS;
    reg [31:0] BLOCKS_LO;
    reg [31:0] BLOCKS_HI;
    reg [31:0] KEY0, KEY1, KEY2, KEY3;
    reg [31:0] IV0,  IV1,  IV2,  IV3;

    // Write FSM (single beat)
    reg aw_hs, w_hs;
    wire write_hs = aw_hs && w_hs;

    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            AWREADY <= 1'b0; WREADY <= 1'b0; BVALID <= 1'b0; BRESP <= 2'b00;
            aw_hs   <= 1'b0; w_hs   <= 1'b0;
        end else begin
            // Address handshake
            if (!AWREADY && AWVALID) begin
                AWREADY <= 1'b1; aw_hs <= 1'b1;
            end else begin
                AWREADY <= 1'b0;
            end
            // Data handshake
            if (!WREADY && WVALID) begin
                WREADY <= 1'b1; w_hs <= 1'b1;
            end else begin
                WREADY <= 1'b0;
            end
            // Response
            if (write_hs) begin
                BVALID <= 1'b1; BRESP <= 2'b00;
                aw_hs  <= 1'b0; w_hs <= 1'b0;
            end else if (BVALID && BREADY) begin
                BVALID <= 1'b0;
            end
        end
    end

    // Write logic
    wire [ADDR_W-1:0] waddr = AWADDR;
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            CTRL <= 32'd0; STATUS <= 32'd0; BLOCKS_LO <= 32'd0; BLOCKS_HI <= 32'd0;
            KEY0 <= 32'd0; KEY1 <= 32'd0; KEY2 <= 32'd0; KEY3 <= 32'd0;
            IV0  <= 32'd0; IV1  <= 32'd0; IV2  <= 32'd0; IV3  <= 32'd0;
            ctrl_start_pulse <= 1'b0; ctrl_soft_reset <= 1'b0; ctrl_keyiv_valid <= 1'b0;
            key <= 128'd0; iv <= 128'd0;
        end else begin
            ctrl_start_pulse <= 1'b0; // self-clear
            if (write_hs) begin
                case (waddr[5:2]) // word-aligned offsets
                    4'h0: begin
                        CTRL <= (WDATA & 32'h00000103); // mask supported bits
                        ctrl_start_pulse <= WDATA[0];
                        ctrl_soft_reset  <= WDATA[1];
                        ctrl_keyiv_valid <= WDATA[8];
                    end
                    4'h2: BLOCKS_LO <= WDATA; // allow SW to clear
                    4'h3: BLOCKS_HI <= WDATA;
                    4'h4: KEY0 <= WDATA;
                    4'h5: KEY1 <= WDATA;
                    4'h6: KEY2 <= WDATA;
                    4'h7: KEY3 <= WDATA;
                    4'h8: IV0  <= WDATA;
                    4'h9: IV1  <= WDATA;
                    4'hA: IV2  <= WDATA;
                    4'hB: IV3  <= WDATA;
                    default: ;
                endcase
            end
            // Update packed key/iv for convenience
            key <= {KEY3, KEY2, KEY1, KEY0};
            iv  <= {IV3, IV2, IV1, IV0};
        end
    end

    // Read FSM
    reg ar_hs;
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            ARREADY <= 1'b0; RVALID <= 1'b0; RRESP <= 2'b00; RDATA <= 32'd0; ar_hs <= 1'b0;
        end else begin
            if (!ARREADY && ARVALID) begin
                ARREADY <= 1'b1; ar_hs <= 1'b1;
            end else begin
                ARREADY <= 1'b0;
            end
            if (ar_hs) begin
                RVALID <= 1'b1; RRESP <= 2'b00;
                ar_hs  <= 1'b0;
            end else if (RVALID && RREADY) begin
                RVALID <= 1'b0;
            end
        end
    end

    // STATUS reflect inputs
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            STATUS <= 32'd0;
        end else begin
            STATUS[0]   <= sts_busy;
            STATUS[1]   <= sts_error;
            STATUS[2]   <= ctrl_keyiv_valid; // latched
            STATUS[31:16] <= sts_fifo_in_level[15:0]; // simple encoding (in)
        end
    end

    // Blocks processed reflect 64-bit counter
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            BLOCKS_LO <= 32'd0; BLOCKS_HI <= 32'd0;
        end else begin
            BLOCKS_LO <= sts_blocks_processed[31:0];
            BLOCKS_HI <= sts_blocks_processed[63:32];
        end
    end

    // Read mux: compute read data on AR handshake to avoid combinational always block
    function automatic [31:0] read_mux;
        input [3:0] idx;
        begin
            case (idx)
                4'h0: read_mux = CTRL;
                4'h1: read_mux = STATUS;
                4'h2: read_mux = BLOCKS_LO;
                4'h3: read_mux = BLOCKS_HI;
                4'h4: read_mux = KEY0;
                4'h5: read_mux = KEY1;
                4'h6: read_mux = KEY2;
                4'h7: read_mux = KEY3;
                4'h8: read_mux = IV0;
                4'h9: read_mux = IV1;
                4'hA: read_mux = IV2;
                4'hB: read_mux = IV3;
                default: read_mux = 32'd0;
            endcase
        end
    endfunction

    // Latch RDATA when AR handshake occurs
    always @(posedge ACLK or negedge ARESETN) begin
        if (!ARESETN) begin
            RDATA <= 32'd0;
        end else if (!ARREADY && ARVALID) begin
            RDATA <= read_mux(ARADDR[5:2]);
        end
    end
endmodule
