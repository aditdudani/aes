// AES AXI-Lite Configuration Module
// Automatically writes Key and IV to the AES core via AXI-Lite interface
// Then sends START command to begin encryption

module aes_axil_config #(
    parameter [127:0] AES_KEY = 128'h2b7e151628aed2a6abf7158809cf4f3c,  // NIST test key
    parameter [127:0] AES_IV  = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff   // Initial counter
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_config,    // Pulse to begin configuration
    output reg         config_done,     // Asserted when complete
    
    // AXI-Lite Master to AES control registers
    output reg  [5:0]  m_axil_awaddr,
    output reg         m_axil_awvalid,
    input  wire        m_axil_awready,
    output reg  [31:0] m_axil_wdata,
    output reg  [3:0]  m_axil_wstrb,
    output reg         m_axil_wvalid,
    input  wire        m_axil_wready,
    input  wire [1:0]  m_axil_bresp,
    input  wire        m_axil_bvalid,
    output reg         m_axil_bready,
    output reg  [5:0]  m_axil_araddr,
    output reg         m_axil_arvalid,
    input  wire        m_axil_arready,
    input  wire [31:0] m_axil_rdata,
    input  wire [1:0]  m_axil_rresp,
    input  wire        m_axil_rvalid,
    output reg         m_axil_rready
);

    reg [3:0] step;
    reg       aw_done, w_done;
    
    // Configuration steps
    localparam IDLE  = 4'd0;
    localparam KEY0  = 4'd1;
    localparam KEY1  = 4'd2;
    localparam KEY2  = 4'd3;
    localparam KEY3  = 4'd4;
    localparam IV0   = 4'd5;
    localparam IV1   = 4'd6;
    localparam IV2   = 4'd7;
    localparam IV3   = 4'd8;
    localparam START = 4'd9;
    localparam DONE  = 4'd10;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step <= IDLE;
            config_done <= 1'b0;
            m_axil_awvalid <= 1'b0;
            m_axil_wvalid <= 1'b0;
            m_axil_bready <= 1'b1;
            m_axil_arvalid <= 1'b0;
            m_axil_rready <= 1'b1;
            m_axil_wstrb <= 4'hF;
            aw_done <= 1'b0;
            w_done <= 1'b0;
            m_axil_awaddr <= 6'd0;
            m_axil_wdata <= 32'd0;
            m_axil_araddr <= 6'd0;
        end else begin
            // Clear handshake flags when acknowledged
            if (m_axil_awready && m_axil_awvalid) begin
                m_axil_awvalid <= 1'b0;
                aw_done <= 1'b1;
            end
            if (m_axil_wready && m_axil_wvalid) begin
                m_axil_wvalid <= 1'b0;
                w_done <= 1'b1;
            end
            
            case (step)
                IDLE: begin
                    config_done <= 1'b0;
                    if (start_config) begin
                        step <= KEY0;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                KEY0: begin
                    m_axil_awaddr <= 6'h10;  // KEY0 register offset
                    m_axil_wdata <= AES_KEY[31:0];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= KEY1;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                KEY1: begin
                    m_axil_awaddr <= 6'h14;
                    m_axil_wdata <= AES_KEY[63:32];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= KEY2;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                KEY2: begin
                    m_axil_awaddr <= 6'h18;
                    m_axil_wdata <= AES_KEY[95:64];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= KEY3;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                KEY3: begin
                    m_axil_awaddr <= 6'h1C;
                    m_axil_wdata <= AES_KEY[127:96];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= IV0;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                IV0: begin
                    m_axil_awaddr <= 6'h20;
                    m_axil_wdata <= AES_IV[31:0];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= IV1;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                IV1: begin
                    m_axil_awaddr <= 6'h24;
                    m_axil_wdata <= AES_IV[63:32];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= IV2;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                IV2: begin
                    m_axil_awaddr <= 6'h28;
                    m_axil_wdata <= AES_IV[95:64];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= IV3;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                IV3: begin
                    m_axil_awaddr <= 6'h2C;
                    m_axil_wdata <= AES_IV[127:96];
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= START;
                        aw_done <= 1'b0;
                        w_done <= 1'b0;
                    end
                end
                
                START: begin
                    m_axil_awaddr <= 6'h00;  // CTRL register
                    m_axil_wdata <= 32'h00000101;  // bit[0]=START, bit[8]=KEY_IV_VALID
                    if (!aw_done) m_axil_awvalid <= 1'b1;
                    if (!w_done) m_axil_wvalid <= 1'b1;
                    if (aw_done && w_done && m_axil_bvalid) begin
                        step <= DONE;
                        config_done <= 1'b1;
                    end
                end
                
                DONE: begin
                    if (!start_config) step <= IDLE;
                end
            endcase
        end
    end

endmodule
